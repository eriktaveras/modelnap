import Foundation

/// Memoria del Mac con los mismos criterios que el Monitor de Actividad:
/// «memoria usada» = memoria de apps + fija + comprimida, y la presión es la que
/// publica el kernel (la que colorea la gráfica del Monitor).
struct SystemMemory: Equatable {
    enum Pressure: Equatable { case normal, warning, critical }

    let total: Int64
    let used: Int64
    let pressure: Pressure

    static func current() -> SystemMemory {
        let total = Int64(ProcessInfo.processInfo.physicalMemory)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &stats) { p in
            p.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        var used: Int64 = 0
        if kr == KERN_SUCCESS {
            let page = Int64(vm_kernel_page_size)
            let app = Int64(stats.internal_page_count) - Int64(stats.purgeable_count)
            used = (app + Int64(stats.wire_count) + Int64(stats.compressor_page_count)) * page
        }

        var level: Int32 = 1
        var size = MemoryLayout<Int32>.size
        sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0)
        let pressure: Pressure = level >= 4 ? .critical : level >= 2 ? .warning : .normal

        return SystemMemory(total: total, used: min(max(used, 0), total), pressure: pressure)
    }
}

extension Int64 {
    /// En GiB, como el Monitor de Actividad (un Mac de 48 GB muestra «48 GB»).
    var memoryGB: String {
        String(format: "%.1f GB", Double(self) / 1_073_741_824)
    }
}
