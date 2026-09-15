import AppKit

// MARK: - cómo arranca Ollama en este Mac

/// Cada Mac lo arranca distinto, y apagarlo mal no sirve: con un LaunchAgent
/// con `KeepAlive`, matar el proceso hace que launchd lo relance al instante.
/// Por eso primero se detecta el mecanismo y se apaga por ese mismo camino.
enum Backend: Equatable {
    /// `brew services start ollama` o un LaunchAgent propio.
    case launchAgent(label: String, plist: String)
    /// La app oficial de ollama.com: al cerrarla se va su servidor.
    case app(URL)
    /// Solo el binario (`ollama serve` a mano o desde un script).
    case binary(String)
    case missing

    var summary: String {
        switch self {
        case .launchAgent(let label, _):
            return label == "homebrew.mxcl.ollama" ? "brew services" : label
        case .app: return "Ollama.app"
        case .binary: return "ollama serve"
        case .missing: return "no instalado"
        }
    }

    var logURL: URL? {
        let fm = FileManager.default
        switch self {
        case .launchAgent(_, let plist):
            let dict = NSDictionary(contentsOfFile: plist)
            let path = (dict?["StandardErrorPath"] as? String) ?? (dict?["StandardOutPath"] as? String)
            return path.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
        case .app:
            return fm.homeDirectoryForCurrentUser.appendingPathComponent(".ollama/logs/server.log")
        case .binary:
            return Paths.ownLog
        case .missing:
            return nil
        }
    }
}

enum Paths {
    static var logsDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Interruptor Ollama")
    }
    static var ownLog: URL { logsDir.appendingPathComponent("ollama.log") }
    static let download = URL(string: "https://ollama.com/download")!
    static let brand = URL(string: "https://taverassolutions.com")!
}

enum Shell {
    struct Result { let status: Int32; let output: String }

    @discardableResult
    static func run(_ tool: String, _ args: [String]) -> Result {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do { try p.run() } catch { return Result(status: -1, output: error.localizedDescription) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return Result(status: p.terminationStatus,
                      output: String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

enum Launchd {
    static var domain: String { "gui/\(getuid())" }

    static func isLoaded(_ label: String) -> Bool {
        Shell.run("/bin/launchctl", ["print", "\(domain)/\(label)"]).status == 0
    }

    static func start(label: String, plist: String) -> String? {
        let r = isLoaded(label)
            ? Shell.run("/bin/launchctl", ["kickstart", "\(domain)/\(label)"])
            : Shell.run("/bin/launchctl", ["bootstrap", domain, plist])
        return r.status == 0 ? nil : "launchctl: \(r.output)"
    }

    static func stop(label: String) -> String? {
        guard isLoaded(label) else { return nil }
        let r = Shell.run("/bin/launchctl", ["bootout", "\(domain)/\(label)"])
        return r.status == 0 ? nil : "launchctl: \(r.output)"
    }

    /// LaunchAgents del usuario que ejecutan `ollama serve`, incluido el de brew.
    static func ollamaAgents() -> [(label: String, plist: String)] {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents")
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "plist" }.compactMap { url in
            guard let dict = NSDictionary(contentsOf: url),
                  let label = dict["Label"] as? String else { return nil }
            var argv = (dict["ProgramArguments"] as? [String]) ?? []
            if let program = dict["Program"] as? String { argv.insert(program, at: 0) }
            let joined = argv.joined(separator: " ").lowercased()
            guard joined.contains("ollama"), joined.contains("serve") else { return nil }
            return (label, url.path)
        }
        .sorted { $0.label < $1.label }
    }
}

enum Detector {
    static let bundleIDs: Set<String> = ["com.electron.ollama", "com.ollama.ollama"]

    static func runningApp() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { app in
            if let id = app.bundleIdentifier, bundleIDs.contains(id) { return true }
            return app.bundleURL?.lastPathComponent == "Ollama.app"
        }
    }

    static func installedApp() -> URL? {
        for id in bundleIDs {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) { return url }
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return ["/Applications/Ollama.app", "\(home)/Applications/Ollama.app"]
            .first { FileManager.default.fileExists(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
    }

    static func binary() -> String? {
        ["/opt/homebrew/bin/ollama", "/usr/local/bin/ollama", "/Applications/Ollama.app/Contents/Resources/ollama"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Orden: lo que está en marcha manda sobre lo que solo está instalado.
    static func detect() -> Backend {
        if let app = runningApp() {
            return .app(app.bundleURL ?? installedApp() ?? URL(fileURLWithPath: "/Applications/Ollama.app"))
        }
        let agents = Launchd.ollamaAgents()
        if let active = agents.first(where: { Launchd.isLoaded($0.label) }) {
            return .launchAgent(label: active.label, plist: active.plist)
        }
        if !serverPIDs().isEmpty, let bin = binary() {
            return .binary(bin)
        }
        if let app = installedApp() { return .app(app) }
        if let agent = agents.first { return .launchAgent(label: agent.label, plist: agent.plist) }
        if let bin = binary() { return .binary(bin) }
        return .missing
    }

    /// PIDs de `ollama serve` del usuario (no los `ollama runner`, que cuelgan del servidor).
    static func serverPIDs() -> [pid_t] {
        let r = Shell.run("/usr/bin/pgrep", ["-u", "\(getuid())", "-f", "ollama serve"])
        return r.output.split(separator: "\n").compactMap { pid_t($0) }
    }
}

// MARK: - encender y apagar

enum Power: Equatable {
    case off
    case starting
    case on
    case stopping
    case missing

    var isUp: Bool { self == .on }
    var isTransition: Bool { self == .starting || self == .stopping }
}

enum Switch {
    /// Devuelve un mensaje de error legible, o nil si fue bien. Bloquea: llamar fuera del hilo principal.
    static func start(_ backend: Backend) -> String? {
        switch backend {
        case .launchAgent(let label, let plist):
            return Launchd.start(label: label, plist: plist)
        case .app(let url):
            let sem = DispatchSemaphore(value: 0)
            var failure: String?
            let config = NSWorkspace.OpenConfiguration()
            config.activates = false
            config.addsToRecentItems = false
            NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
                failure = error?.localizedDescription
                sem.signal()
            }
            sem.wait()
            return failure
        case .binary(let path):
            try? FileManager.default.createDirectory(at: Paths.logsDir, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: Paths.ownLog.path) {
                FileManager.default.createFile(atPath: Paths.ownLog.path, contents: nil)
            }
            guard let log = try? FileHandle(forWritingTo: Paths.ownLog) else { return "No puedo escribir el log" }
            log.seekToEndOfFile()
            let p = Process()
            p.executableURL = URL(fileURLWithPath: path)
            p.arguments = ["serve"]
            p.standardOutput = log
            p.standardError = log
            do { try p.run() } catch { return error.localizedDescription }
            return nil
        case .missing:
            return "Ollama no está instalado."
        }
    }

    static func stop(_ backend: Backend) -> String? {
        switch backend {
        case .launchAgent(let label, _):
            return Launchd.stop(label: label)
        case .app:
            Detector.runningApp()?.terminate()
            // Si la app no cierra en 10 s, se apaga el servidor directamente.
            for _ in 0..<20 where Detector.runningApp() != nil { usleep(500_000) }
            Detector.runningApp()?.forceTerminate()
            killServers()
            return nil
        case .binary:
            killServers()
            return nil
        case .missing:
            return nil
        }
    }

    private static func killServers() {
        for pid in Detector.serverPIDs() { kill(pid, SIGTERM) }
    }
}

// MARK: - API de Ollama

struct LoadedModel: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let bytes: Int64
    let context: Int?
}

struct InstalledModel: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let bytes: Int64
    let quantization: String?
    let vision: Bool
    let tools: Bool
}

enum OllamaAPI {
    /// Respeta OLLAMA_HOST si la app se lanzó con él; si no, el puerto de siempre.
    static let base: URL = {
        if let raw = ProcessInfo.processInfo.environment["OLLAMA_HOST"], !raw.isEmpty {
            let withScheme = raw.contains("://") ? raw : "http://\(raw)"
            if let url = URL(string: withScheme.replacingOccurrences(of: "0.0.0.0", with: "127.0.0.1")) {
                return url
            }
        }
        return URL(string: "http://127.0.0.1:11434")!
    }()

    static var hostLabel: String { "\(base.host ?? "127.0.0.1"):\(base.port ?? 11434)" }

    private static let quick: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 1.5
        c.timeoutIntervalForResource = 3
        return URLSession(configuration: c)
    }()

    /// Cargar un modelo grande en frío tarda; no cortamos antes de tiempo.
    private static let slow: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 600
        c.timeoutIntervalForResource = 900
        return URLSession(configuration: c)
    }()

    private static func json(_ path: String) async -> [String: Any]? {
        guard let (data, resp) = try? await quick.data(from: base.appendingPathComponent(path)),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    static func version() async -> String? {
        await json("api/version")?["version"] as? String
    }

    static func loaded() async -> [LoadedModel] {
        let list = await json("api/ps")?["models"] as? [[String: Any]] ?? []
        return list.compactMap { m in
            guard let name = m["name"] as? String else { return nil }
            let vram = (m["size_vram"] as? NSNumber)?.int64Value
            let size = (m["size"] as? NSNumber)?.int64Value
            return LoadedModel(name: name,
                               bytes: vram ?? size ?? 0,
                               context: (m["context_length"] as? NSNumber)?.intValue)
        }
    }

    static func installed() async -> [InstalledModel] {
        let list = await json("api/tags")?["models"] as? [[String: Any]] ?? []
        return list.compactMap { m in
            guard let name = m["name"] as? String else { return nil }
            let details = m["details"] as? [String: Any]
            let caps = m["capabilities"] as? [String] ?? []
            let quant = (details?["quantization_level"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            return InstalledModel(name: name,
                                  bytes: (m["size"] as? NSNumber)?.int64Value ?? 0,
                                  quantization: quant,
                                  vision: caps.contains("vision"),
                                  tools: caps.contains("tools"))
        }
        .sorted { $0.name < $1.name }
    }

    /// Sin prompt, `/api/generate` solo carga o descarga: keep_alive -1 lo deja
    /// en memoria indefinidamente, 0 lo libera ya.
    static func setKeepAlive(model: String, _ keepAlive: Int) async -> String? {
        var req = URLRequest(url: base.appendingPathComponent("api/generate"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["model": model, "keep_alive": keepAlive])
        do {
            let (data, resp) = try await slow.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if code == 200 { return nil }
            let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            return body?["error"] as? String ?? "Ollama respondió \(code)"
        } catch {
            return error.localizedDescription
        }
    }
}

// MARK: - estado para la interfaz

@MainActor
final class OllamaController: ObservableObject {
    @Published private(set) var power: Power = .off
    @Published private(set) var backend: Backend = .missing
    @Published private(set) var version: String?
    @Published private(set) var loaded: [LoadedModel] = []
    @Published private(set) var installed: [InstalledModel] = []
    @Published private(set) var busyModel: String?
    @Published var error: String?

    var onPowerChange: ((Power) -> Void)?

    private var transition: (target: Power, since: Date)?
    /// El último mecanismo con el que Ollama estuvo encendido. Apagado, la
    /// detección solo ve lo instalado (p. ej. Ollama.app y además un agente de
    /// brew) y podría encenderlo por otro camino distinto al que usas.
    private var lastActive: Backend?
    private var timer: Timer?
    private var refreshing = false

    let totalMemory = Int64(ProcessInfo.processInfo.physicalMemory)

    func startPolling() {
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Task { await self.refresh() }
            }
        }
    }

    func refresh() async {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }

        // Mientras se apaga no se vuelve a detectar: la app o el agente pueden
        // desaparecer a mitad y la detección caería en otro mecanismo.
        let v = await OllamaAPI.version()
        version = v
        if transition?.target != .stopping {
            let detected = await Task.detached { Detector.detect() }.value
            if v != nil {
                backend = detected
                lastActive = detected
            } else {
                backend = lastActive ?? detected
            }
        }

        if v != nil {
            async let l = OllamaAPI.loaded()
            async let i = OllamaAPI.installed()
            loaded = await l
            let list = await i
            if !list.isEmpty || installed.isEmpty { installed = list }
        } else {
            loaded = []
        }

        setPower(derive(up: v != nil))
    }

    private func derive(up: Bool) -> Power {
        if let t = transition {
            let elapsed = Date().timeIntervalSince(t.since)
            switch t.target {
            case .starting:
                if up { transition = nil; return .on }
                if elapsed > 90 {
                    transition = nil
                    error = "Ollama no respondió en 90 s. Revisa el log (clic derecho en el ícono)."
                    return .off
                }
                return .starting
            case .stopping:
                if !up { transition = nil; return .off }
                if elapsed > 30 {
                    transition = nil
                    error = "Ollama sigue respondiendo. Puede que lo haya arrancado otro programa."
                    return .on
                }
                return .stopping
            default:
                transition = nil
            }
        }
        if up { return .on }
        return backend == .missing ? .missing : .off
    }

    private func setPower(_ p: Power) {
        guard p != power else { return }
        power = p
        onPowerChange?(p)
    }

    func toggle() { setOn(!(power.isUp || power == .starting)) }

    func setOn(_ on: Bool) {
        error = nil
        if backend == .missing {
            NSWorkspace.shared.open(Paths.download)
            return
        }
        let target = backend
        transition = (on ? .starting : .stopping, Date())
        setPower(on ? .starting : .stopping)
        Task {
            let failure = await Task.detached { on ? Switch.start(target) : Switch.stop(target) }.value
            if let failure {
                error = failure
                transition = nil
            }
            await refresh()
        }
    }

    func load(_ model: String) { keepAlive(model, -1) }
    func unload(_ model: String) { keepAlive(model, 0) }

    private func keepAlive(_ model: String, _ value: Int) {
        guard busyModel == nil else { return }
        error = nil
        busyModel = model
        Task {
            if let failure = await OllamaAPI.setKeepAlive(model: model, value) {
                error = failure
            }
            busyModel = nil
            await refresh()
        }
    }
}

extension Int64 {
    var gigabytes: String {
        String(format: "%.1f GB", Double(self) / 1_000_000_000)
    }
}
