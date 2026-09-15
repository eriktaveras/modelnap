import Carbon.HIToolbox

/// Atajo global ⌥⌘O. `RegisterEventHotKey` de Carbon sigue siendo la vía que no
/// pide permiso de Accesibilidad: el sistema solo avisa cuando se pulsa esa
/// combinación exacta, sin leer el resto del teclado.
final class HotKey {
    static let display = "⌥⌘O"

    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    /// Devuelve false si otra app ya tiene la combinación.
    @discardableResult
    func register() -> Bool {
        guard ref == nil else { return true }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let me = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { hotKey.action() }
            return noErr
        }, 1, &spec, me, &handler)

        let id = EventHotKeyID(signature: OSType(0x544F4C4C), id: 1)   // 'TOLL'
        let status = RegisterEventHotKey(UInt32(kVK_ANSI_O), UInt32(cmdKey | optionKey), id,
                                         GetApplicationEventTarget(), 0, &ref)
        if status != noErr {
            unregister()
            return false
        }
        return true
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
        ref = nil
        handler = nil
    }

    deinit { unregister() }
}
