import AppKit
import SwiftUI
import ServiceManagement

// Uso por terminal, con el mismo camino que el interruptor del panel:
//   InterruptorOllama --status | --on | --off
//   InterruptorOllama --snapshot salida.png [dark|light]
if let flag = CommandLine.arguments.dropFirst().first(where: { ["--status", "--on", "--off"].contains($0) }) {
    func apiUp() -> Bool {
        let sem = DispatchSemaphore(value: 0)
        var up = false
        Task.detached { up = await OllamaAPI.version() != nil; sem.signal() }
        sem.wait()
        return up
    }
    func wait(for up: Bool, seconds: Int) -> Bool {
        for _ in 0..<(seconds * 2) {
            if apiUp() == up { return true }
            usleep(500_000)
        }
        return false
    }
    let backend = Detector.detect()
    switch flag {
    case "--on":
        if let e = Switch.start(backend) { print(e); exit(1) }
        print(wait(for: true, seconds: 90) ? "encendido (\(backend.summary))" : "no respondió en 90 s"); exit(0)
    case "--off":
        if let e = Switch.stop(backend) { print(e); exit(1) }
        print(wait(for: false, seconds: 30) ? "apagado (\(backend.summary))" : "sigue respondiendo"); exit(0)
    default:
        print("mecanismo: \(backend.summary) · API \(OllamaAPI.hostLabel): \(apiUp() ? "responde" : "no responde")")
        exit(0)
    }
}

/// Preferencias de la app que la interfaz necesita observar.
@MainActor
final class Prefs: ObservableObject {
    private let askedKey = "loginItemAsked"
    @Published private(set) var shouldOfferLogin: Bool

    init() {
        shouldOfferLogin = !UserDefaults.standard.bool(forKey: askedKey)
            && SMAppService.mainApp.status != .enabled
    }

    var opensAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    func answerLogin(_ yes: Bool) {
        UserDefaults.standard.set(true, forKey: askedKey)
        shouldOfferLogin = false
        if yes { try? SMAppService.mainApp.register() }
    }

    func toggleLogin() throws {
        UserDefaults.standard.set(true, forKey: askedKey)
        shouldOfferLogin = false
        if opensAtLogin {
            try SMAppService.mainApp.unregister()
        } else {
            try SMAppService.mainApp.register()
        }
    }
}

if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), CommandLine.arguments.count > i + 1 {
    let out = URL(fileURLWithPath: CommandLine.arguments[i + 1])
    let dark = CommandLine.arguments.dropFirst(i + 2).first != "light"
    MainActor.assumeIsolated {
        Brand.registerFonts()
        let ollama = OllamaController()
        let prefs = Prefs()
        Task { @MainActor in
            await ollama.refresh()
            let view = ContentView(ollama: ollama, prefs: prefs)
                .environment(\.colorScheme, dark ? .dark : .light)
            let r = ImageRenderer(content: view)
            r.scale = 2
            if let img = r.nsImage, let tiff = img.tiffRepresentation,
               let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? png.write(to: out)
                print("captura: \(out.path)")
            }
            exit(0)
        }
        RunLoop.main.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let ollama = OllamaController()
    private let prefs = Prefs()
    private var blink: Timer?
    private var blinkOn = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        Brand.registerFonts()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let hosting = NSHostingController(rootView: ContentView(ollama: ollama, prefs: prefs))
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.animates = true

        ollama.onPowerChange = { [weak self] p in self?.paint(p) }
        paint(ollama.power)
        ollama.startPolling()

        // Primera vez: se abre el panel para que se vea dónde vive y qué hace.
        if prefs.shouldOfferLogin {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.togglePopover() }
        }
    }

    // MARK: - ícono

    private func paint(_ power: Power) {
        blink?.invalidate()
        blink = nil
        guard let button = statusItem.button else { return }
        switch power {
        case .on:
            button.image = Mark.statusImage(dot: .on, dimmed: false)
            button.toolTip = "Ollama encendido"
        case .off:
            button.image = Mark.statusImage(dot: .none, dimmed: true)
            button.toolTip = "Ollama apagado"
        case .missing:
            button.image = Mark.statusImage(dot: .none, dimmed: true)
            button.toolTip = "Ollama no está instalado"
        case .starting, .stopping:
            button.toolTip = power == .starting ? "Ollama arrancando…" : "Ollama apagándose…"
            blinkOn = true
            button.image = Mark.statusImage(dot: .busy, dimmed: false)
            blink = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, let b = self.statusItem.button else { return }
                    self.blinkOn.toggle()
                    b.image = Mark.statusImage(dot: self.blinkOn ? .busy : .none, dimmed: !self.blinkOn)
                }
            }
        }
    }

    // MARK: - clics

    @objc private func statusClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            Task { await ollama.refresh() }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        switch ollama.power {
        case .missing:
            add(menu, "Descargar Ollama…", #selector(togglePower))
        default:
            let power = add(menu, ollama.power == .on ? "Apagar Ollama" : "Encender Ollama", #selector(togglePower))
            power.isEnabled = !ollama.power.isTransition
        }

        menu.addItem(.separator())

        let logs = add(menu, "Ver el log de Ollama", #selector(openLogs))
        logs.isEnabled = ollama.backend.logURL != nil

        let login = add(menu, "Abrir al iniciar sesión", #selector(toggleLogin))
        login.state = prefs.opensAtLogin ? .on : .off

        menu.addItem(.separator())
        add(menu, "Acerca de Interruptor Ollama", #selector(showAbout))
        add(menu, "Taveras Solutions", #selector(openBrand))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Salir", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @discardableResult
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    @objc private func togglePower() { ollama.toggle() }

    @objc private func openLogs() {
        guard let url = ollama.backend.logURL else { return }
        if let console = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Console") {
            NSWorkspace.shared.open([url], withApplicationAt: console, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func toggleLogin() {
        do { try prefs.toggleLogin() } catch {
            ollama.error = "Inicio de sesión: \(error.localizedDescription)"
        }
    }

    @objc private func openBrand() { NSWorkspace.shared.open(Paths.brand) }

    @objc private func showAbout() {
        let credits = NSMutableAttributedString(
            string: "Hecho por Taveras Solutions LLC\ntaverassolutions.com\n\nProyecto independiente, no afiliado a Ollama.",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor])
        let link = (credits.string as NSString).range(of: "taverassolutions.com")
        credits.addAttribute(.link, value: Paths.brand, range: link)
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        credits.addAttribute(.paragraphStyle, value: centered, range: NSRange(location: 0, length: credits.length))

        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)   // vive en la barra de menús, no en el Dock
    app.run()
}
