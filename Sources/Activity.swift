import Foundation

/// Ollama no expone cuándo fue la última petición, pero su proceso `ollama runner`
/// (uno por modelo cargado) solo gasta CPU mientras procesa. Medido en un M4 con
/// gemma4 26B: 0,06 s de CPU en 30 s de reposo frente a 0,99 s al generar 104
/// tokens. Con esa diferencia basta mirar cuánto CPU sumó desde la última muestra.
enum ProcessCPU {
    private static let timebase: Double = {
        var tb = mach_timebase_info_data_t()
        mach_timebase_info(&tb)
        return Double(tb.numer) / Double(tb.denom)
    }()

    /// Segundos de CPU (usuario + sistema) acumulados por el proceso, o nil si ya no existe.
    static func seconds(_ pid: pid_t) -> Double? {
        var info = rusage_info_v4()
        let r = withUnsafeMutablePointer(to: &info) { p in
            p.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        guard r == 0 else { return nil }
        return Double(info.ri_user_time + info.ri_system_time) * timebase / 1e9
    }

    static func runnerPIDs() -> [pid_t] {
        let r = Shell.run("/usr/bin/pgrep", ["-u", "\(getuid())", "-f", "ollama runner"])
        return r.output.split(separator: "\n").compactMap { pid_t($0) }
    }
}

/// Lógica pura del «sin uso», separada de los procesos para poder probarla.
struct IdleTracker {
    /// CPU por encima de la cual una muestra cuenta como uso. El reposo medido
    /// ronda 0,005 s cada 2,5 s; generar unos pocos tokens ya supera 0,1 s.
    static let activityThreshold = 0.08

    private(set) var lastActivity: Date
    private var lastCPU: [pid_t: Double] = [:]
    private var lastModels: Set<String> = []

    init(now: Date = Date()) { lastActivity = now }

    /// `cpu` son los segundos acumulados por cada runner vivo en este instante.
    mutating func sample(cpu: [pid_t: Double], models: Set<String>, now: Date = Date()) {
        defer {
            lastCPU = cpu
            lastModels = models
        }
        // Un modelo nuevo o un runner que cambia (recarga) es uso aunque aún no gaste CPU.
        if models != lastModels || Set(cpu.keys) != Set(lastCPU.keys) {
            lastActivity = now
            return
        }
        let delta = cpu.reduce(0.0) { acc, entry in
            acc + max(0, entry.value - (lastCPU[entry.key] ?? entry.value))
        }
        if delta >= Self.activityThreshold { lastActivity = now }
    }

    /// Algo que el usuario hizo a mano (cargar desde el panel) también cuenta.
    mutating func touch(now: Date = Date()) { lastActivity = now }

    func idleSeconds(now: Date = Date()) -> TimeInterval { now.timeIntervalSince(lastActivity) }
}
