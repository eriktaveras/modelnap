import AppKit

// MARK: - Splash (Inco AI)

/// Splash es otro motor local, con API compatible con OpenAI en 127.0.0.1:8000.
/// A diferencia de Ollama no carga y descarga modelos: `splash serve --model X`
/// reserva la memoria al arrancar y la suelta al salir. Liberar = apagar.
///
/// Cómo corre (Splash 1.0): `splash serve` es un script que hace exec de
/// `python3 …/server/server.py … --model X`, y ese servidor lanza el motor nativo
/// `…/engine/splash` como hijo. Mientras sirve, deja su PID y el modelo en
/// runtime/serve.lock (el archivo queda al salir, así que se comprueba el PID).
enum SplashCLI {
    static func binary() -> String? {
        ["/opt/homebrew/bin/splash", "/usr/local/bin/splash"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static var dataDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Splash")
    }

    static var ownLog: URL { Paths.logsDir.appendingPathComponent("splash.log") }

    /// Modelos preparados en models/<dueño>/<repo> (enlaces a la caché de Hugging Face).
    static func installedModels() -> [SplashModel] {
        let fm = FileManager.default
        let root = dataDir.appendingPathComponent("models")
        let owners = (try? fm.contentsOfDirectory(atPath: root.path)) ?? []
        var out: [SplashModel] = []
        for owner in owners where !owner.hasPrefix(".") {
            let repos = (try? fm.contentsOfDirectory(atPath: root.appendingPathComponent(owner).path)) ?? []
            for repo in repos where !repo.hasPrefix(".") {
                let dir = root.appendingPathComponent(owner).appendingPathComponent(repo)
                out.append(SplashModel(id: "\(owner)/\(repo)", bytes: diskSize(dir)))
            }
        }
        return out.sorted { $0.id < $1.id }
    }

    /// Tamaño siguiendo enlaces: la caché de Hugging Face guarda los archivos
    /// como enlaces a blobs.
    private static func diskSize(_ dir: URL) -> Int64 {
        let resolved = dir.resolvingSymlinksInPath()
        guard let walker = FileManager.default.enumerator(at: resolved, includingPropertiesForKeys: nil) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in walker {
            let real = url.resolvingSymlinksInPath()
            if let size = (try? real.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])),
               size.isRegularFile == true {
                total += Int64(size.fileSize ?? 0)
            }
        }
        return total
    }

    /// PIDs del servidor Python (no del motor nativo, que cuelga de él).
    static func serverPIDs() -> [pid_t] {
        let r = Shell.run("/usr/bin/pgrep", ["-u", "\(getuid())", "-f", "server/server.py .*--binary .*/splash"])
        return r.output.split(separator: "\n").compactMap { pid_t($0) }
    }

    /// El servidor y todos sus descendientes: la memoria y el CPU del modelo
    /// están en el motor nativo, no en Python.
    static func processTree(_ roots: [pid_t]) -> [pid_t] {
        var all = roots
        var frontier = roots
        while let pid = frontier.popLast() {
            let r = Shell.run("/usr/bin/pgrep", ["-P", "\(pid)"])
            let kids = r.output.split(separator: "\n").compactMap { pid_t($0) }
            all += kids
            frontier += kids
        }
        return all
    }

    /// Memoria propia de los procesos (la que sí entra en «memoria usada»).
    static func footprint(_ pids: [pid_t]) -> Int64 {
        pids.reduce(0) { acc, pid in
            var info = rusage_info_v4()
            let r = withUnsafeMutablePointer(to: &info) { p in
                p.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
                }
            }
            return r == 0 ? acc + Int64(info.ri_phys_footprint) : acc
        }
    }

    /// Modelo que sirve el proceso vivo, según serve.lock.
    static func lockedModel() -> String? {
        let url = dataDir.appendingPathComponent("runtime/serve.lock")
        guard let data = try? Data(contentsOf: url),
              let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let pid = (dict["pid"] as? NSNumber)?.int32Value,
              serverPIDs().contains(pid) else { return nil }
        return dict["model"] as? String
    }

    /// Arranca desacoplado, con la salida en ~/Library/Logs/ModelNap/splash.log.
    static func start(model: String) -> (Process?, String?) {
        guard let bin = binary() else { return (nil, tr("Splash no está instalado.")) }
        try? FileManager.default.createDirectory(at: Paths.logsDir, withIntermediateDirectories: true)
        // Un log por arranque: así el error de memoria que se lee es el de ahora.
        FileManager.default.createFile(atPath: ownLog.path, contents: nil)
        guard let log = try? FileHandle(forWritingTo: ownLog) else { return (nil, tr("No puedo escribir el log")) }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: bin)
        p.arguments = ["serve", "--model", model]
        p.standardOutput = log
        p.standardError = log
        p.standardInput = FileHandle.nullDevice
        do { try p.run() } catch { return (nil, error.localizedDescription) }
        return (p, nil)
    }

    /// Como Ctrl+C en la terminal; si no sale en 20 s, SIGTERM y luego SIGKILL.
    static func stop() {
        let roots = serverPIDs()
        guard !roots.isEmpty else { return }
        for pid in roots { kill(pid, SIGINT) }
        for _ in 0..<40 where !serverPIDs().isEmpty { usleep(500_000) }
        for pid in serverPIDs() { kill(pid, SIGTERM) }
        for _ in 0..<10 where !serverPIDs().isEmpty { usleep(500_000) }
        for pid in processTree(serverPIDs()) { kill(pid, SIGKILL) }
    }

    /// Traduce el error de arranque de Splash a algo que se entienda.
    static func explainFailure(_ log: String) -> String? {
        // «model loading needs 17355931648 bytes plus 5153960755 bytes protected
        //  for macOS, but only 19196428288 bytes are currently available»
        let pattern = #"needs (\d+) bytes plus (\d+) bytes protected for macOS, but only (\d+) bytes"#
        if let re = try? NSRegularExpression(pattern: pattern),
           let m = re.firstMatch(in: log, range: NSRange(log.startIndex..., in: log)) {
            let n = (1...3).map { i -> Int64 in
                Int64((log as NSString).substring(with: m.range(at: i))) ?? 0
            }
            return tr("Splash necesita %@ libres y hay %@. Cierra apps pesadas (Safari, Chrome) y vuelve a intentarlo.",
                      (n[0] + n[1]).memoryGB, n[2].memoryGB)
        }
        if log.contains("is in use; stop that service first") {
            return tr("El puerto 8000 está ocupado por otro programa.")
        }
        if log.contains("already serving") {
            return tr("Splash ya está sirviendo desde otra terminal.")
        }
        let last = log.split(separator: "\n").last { $0.lowercased().contains("error") }
        return last.map { String($0.prefix(220)) }
    }
}

struct SplashModel: Identifiable, Equatable {
    let id: String
    let bytes: Int64
    var shortName: String { id.split(separator: "/").last.map(String.init) ?? id }
}

enum SplashAPI {
    static let base = URL(string: "http://127.0.0.1:8000")!
    static let hostLabel = "127.0.0.1:8000"

    private static let quick: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 1.5
        c.timeoutIntervalForResource = 3
        return URLSession(configuration: c)
    }()

    static func healthy() async -> Bool {
        guard let (_, resp) = try? await quick.data(from: base.appendingPathComponent("health")) else { return false }
        return (resp as? HTTPURLResponse)?.statusCode == 200
    }

    /// `/status` (schema 5) dice la memoria real del motor y cuántas peticiones
    /// lleva. Los pesos van mapeados desde el archivo, así que ni el Monitor de
    /// Actividad ni el footprint del proceso los ven; y generar apenas gasta
    /// CPU (0,03 s cada 2,5 s: el trabajo es de la GPU), así que el uso tampoco
    /// se puede medir como en Ollama.
    static func status() async -> SplashStatus? {
        guard let (data, resp) = try? await quick.data(from: base.appendingPathComponent("status")),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let d = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        func int(_ path: String...) -> Int64 {
            var o: Any? = d
            for k in path { o = (o as? [String: Any])?[k] }
            return (o as? NSNumber)?.int64Value ?? 0
        }
        let busy = int("http", "requests", "active") + int("scheduler", "queued")
            + int("scheduler", "prefilling") + int("scheduler", "decoding")
        return SplashStatus(ready: d["ready"] as? Bool ?? false,
                            model: (d["instance"] as? [String: Any])?["model"] as? String,
                            bytes: int("memory_actual", "current_bytes"),
                            submitted: int("requests", "submitted"),
                            busy: busy > 0)
    }
}

struct SplashStatus: Equatable {
    let ready: Bool
    let model: String?
    let bytes: Int64
    let submitted: Int64
    let busy: Bool
}

/// «Sin uso» de Splash: una petición nueva o una en curso reinicia el contador.
struct SplashActivity {
    private(set) var lastActivity: Date
    private var lastSubmitted: Int64?

    init(now: Date = Date()) { lastActivity = now }

    mutating func sample(_ s: SplashStatus, now: Date = Date()) {
        if s.busy || (lastSubmitted.map { s.submitted != $0 } ?? true) { lastActivity = now }
        lastSubmitted = s.submitted
    }

    mutating func touch(now: Date = Date()) { lastActivity = now }

    func idleSeconds(now: Date = Date()) -> TimeInterval { now.timeIntervalSince(lastActivity) }
}

// MARK: - estado para la interfaz

@MainActor
final class SplashController: ObservableObject {
    @Published private(set) var power: Power = .missing
    @Published private(set) var models: [SplashModel] = []
    /// Modelo en marcha, o el elegido para el próximo arranque.
    @Published var selected: String = UserDefaults.standard.string(forKey: "splashModel") ?? "" {
        didSet { if !isDemo { UserDefaults.standard.set(selected, forKey: "splashModel") } }
    }
    @Published private(set) var running: String?
    /// Memoria del motor según Splash (pesos incluidos).
    @Published private(set) var footprint: Int64 = 0
    /// Lo que de eso NO sale en la «memoria usada» del Mac: los pesos mapeados
    /// desde el archivo cuentan como caché. Se suma para que la barra cuadre.
    @Published private(set) var outsideUsed: Int64 = 0
    @Published private(set) var idleSeconds: TimeInterval?
    @Published private(set) var autoStopped: Date?
    @Published var error: String?

    /// Minutos sin peticiones tras los que se apaga; 0 = nunca. Es aparte del de
    /// Ollama: apagar Splash cuesta más, porque no vuelve a arrancar solo.
    @Published var idleStopMinutes: Int = UserDefaults.standard.integer(forKey: "splashIdleStopMinutes") {
        didSet {
            if !isDemo { UserDefaults.standard.set(idleStopMinutes, forKey: "splashIdleStopMinutes") }
            tracker.touch()
        }
    }
    /// Vaciar los modelos de Ollama antes de arrancar: Splash exige la memoria libre.
    @Published var freesOllamaFirst: Bool = UserDefaults.standard.object(forKey: "splashFreesOllama") as? Bool ?? true {
        didSet { if !isDemo { UserDefaults.standard.set(freesOllamaFirst, forKey: "splashFreesOllama") } }
    }
    /// Solo para pruebas: límite en segundos que manda sobre los minutos.
    var idleLimitOverride: TimeInterval?
    var idleLimit: TimeInterval? {
        if let idleLimitOverride { return idleLimitOverride }
        return idleStopMinutes > 0 ? TimeInterval(idleStopMinutes * 60) : nil
    }
    var freeOtherEngines: () async -> Void = {}
    var onPowerChange: ((Power) -> Void)?

    var isInstalled: Bool { power != .missing }
    var logURL: URL? {
        FileManager.default.fileExists(atPath: SplashCLI.ownLog.path) ? SplashCLI.ownLog
            : SplashCLI.dataDir.appendingPathComponent("logs/server.log")
    }

    private(set) var isDemo = false
    private var transition: (target: Power, since: Date)?
    private var process: Process?
    private var refreshing = false
    private var tracker = SplashActivity()

    func refresh() async {
        guard !refreshing, !isDemo else { return }
        refreshing = true
        defer { refreshing = false }

        guard SplashCLI.binary() != nil else { setPower(.missing); return }
        if models.isEmpty || power != .on {
            models = await Task.detached { SplashCLI.installedModels() }.value
        }
        let status = await SplashAPI.status()
        let up = status?.ready ?? false
        let (alive, locked, own) = await Task.detached { () -> (Bool, String?, Int64) in
            let roots = SplashCLI.serverPIDs()
            guard !roots.isEmpty else { return (false, nil, 0) }
            return (true, SplashCLI.lockedModel(), SplashCLI.footprint(SplashCLI.processTree(roots)))
        }.value
        running = status?.model ?? locked
        if let running, selected != running { selected = running }
        if running == nil, !models.contains(where: { $0.id == selected }), let first = models.first {
            selected = first.id
        }
        footprint = status?.bytes ?? 0
        outsideUsed = max(0, footprint - own)
        setPower(derive(up: up, alive: alive))
        trackIdle(status)
    }

    private func derive(up: Bool, alive: Bool) -> Power {
        if let t = transition {
            let elapsed = Date().timeIntervalSince(t.since)
            switch t.target {
            case .starting:
                if up { transition = nil; return .on }
                // El proceso murió antes de responder: casi siempre es la memoria.
                if let p = process, !p.isRunning {
                    transition = nil
                    let log = (try? String(contentsOf: SplashCLI.ownLog, encoding: .utf8)) ?? ""
                    error = SplashCLI.explainFailure(log) ?? tr("Splash se cerró al arrancar. Revisa el log.")
                    return .off
                }
                if elapsed > 180 {
                    transition = nil
                    error = tr("Splash no respondió en 3 min. Revisa el log.")
                    return alive ? .on : .off
                }
                return .starting
            case .stopping:
                if !alive && !up { transition = nil; return .off }
                return .stopping
            default:
                transition = nil
            }
        }
        // Vivo pero sin /health todavía: lo arrancó otro (terminal) y está cargando.
        if alive && !up { return .starting }
        return up ? .on : .off
    }

    private func setPower(_ p: Power) {
        guard p != power else { return }
        power = p
        onPowerChange?(p)
    }

    private func trackIdle(_ status: SplashStatus?) {
        guard power == .on, let status else {
            idleSeconds = nil
            tracker.touch()
            return
        }
        tracker.sample(status)
        let idle = tracker.idleSeconds()
        idleSeconds = idle
        guard let limit = idleLimit, idle >= limit else { return }
        autoStopped = Date()
        setOn(false)
    }

    func toggle() { setOn(!(power.isUp || power == .starting)) }

    func setOn(_ on: Bool) {
        guard power != .missing, !power.isTransition, on != power.isUp else { return }
        error = nil
        let model = selected
        guard !on || !model.isEmpty else {
            error = tr("No hay modelos de Splash. Descarga uno con `splash serve --model …`.")
            return
        }
        if on { autoStopped = nil }
        transition = (on ? .starting : .stopping, Date())
        setPower(on ? .starting : .stopping)
        tracker.touch()
        Task {
            if on {
                if freesOllamaFirst { await freeOtherEngines() }
                let (p, failure) = await Task.detached { SplashCLI.start(model: model) }.value
                process = p
                if let failure { error = failure; transition = nil }
            } else {
                await Task.detached { SplashCLI.stop() }.value
                process = nil
            }
            await refresh()
        }
    }

    /// Para las capturas del README.
    func loadDemo() {
        isDemo = true
        models = [SplashModel(id: "incoai/Qwen3.8-27B-Splash", bytes: 17_180_000_000)]
        selected = "incoai/Qwen3.8-27B-Splash"
        running = selected
        footprint = 19_055_050_752
        outsideUsed = 17_300_000_000
        idleSeconds = 3 * 60
        idleStopMinutes = 60
        power = .on
    }
}
