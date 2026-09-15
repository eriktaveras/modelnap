import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var ollama: OllamaController
    @ObservedObject var prefs: Prefs
    @Environment(\.colorScheme) private var scheme
    @State private var showingSettings: Bool

    init(ollama: OllamaController, prefs: Prefs, showingSettings: Bool = false) {
        self.ollama = ollama
        self.prefs = prefs
        _showingSettings = State(initialValue: showingSettings)
    }

    private var t: Theme { Theme.of(scheme) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(t.line).frame(height: 1)

            VStack(spacing: 10) {
                if showingSettings {
                    SettingsView(ollama: ollama, prefs: prefs, theme: t)
                } else {
                    PowerHero(ollama: ollama, theme: t)
                    if let error = ollama.error {
                        Banner(text: error, theme: t) { ollama.error = nil }
                    }
                    if let hotKeyError = prefs.hotKeyError {
                        Banner(text: hotKeyError, theme: t) { prefs.hotKeyError = nil }
                    }
                    if prefs.shouldOfferLogin {
                        LoginOffer(theme: t, accept: { prefs.answerLogin(true) }, decline: { prefs.answerLogin(false) })
                    }
                    if ollama.power != .missing {
                        MemoryCard(ollama: ollama, theme: t)
                        ModelList(ollama: ollama, theme: t)
                    }
                }
            }
            .padding(14)

            Rectangle().fill(t.line).frame(height: 1)
            footer
        }
        .frame(width: 340)
        .background(t.bg)
        .foregroundStyle(t.fg)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 9) {
            Group {
                if showingSettings {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(t.accent)
                } else {
                    Image(nsImage: Mark.logoImage(points: 22, color: NSColor(ollama.power == .on ? t.accent : t.muted)))
                }
            }
            .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(showingSettings ? tr("Ajustes") : "ModelNap")
                    .font(Brand.sans(14, .semibold))
                Text(subtitle)
                    .font(Brand.mono(10))
                    .foregroundStyle(t.muted)
                    .lineLimit(1)
            }
            Spacer()
            if !showingSettings { StatePill(power: ollama.power, theme: t) }
            Button { showingSettings.toggle() } label: {
                Image(systemName: showingSettings ? "xmark" : "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 26, height: 24)
                    .background(RoundedRectangle(cornerRadius: 6).fill(showingSettings ? t.track : .clear))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(t.secondary)
            .help(showingSettings ? tr("Cerrar ajustes") : tr("Ajustes"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var subtitle: String {
        if showingSettings { return "v\(Bundle.main.shortVersion)" }
        if let v = ollama.version { return "v\(v) · \(ollama.backend.summary)" }
        return ollama.backend.summary
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button { NSWorkspace.shared.open(Paths.brand) } label: {
                HStack(spacing: 5) {
                    Circle().fill(t.accent).frame(width: 6, height: 6)
                    Text("Taveras Solutions")
                        .font(Brand.sans(10.5, .semibold))
                        .foregroundStyle(t.secondary)
                }
            }
            .buttonStyle(.plain)
            .help("taverassolutions.com")
            Spacer()
            Text(prefs.hotKeyEnabled ? "\(HotKey.display) · \(tr("No afiliado a Ollama"))" : tr("No afiliado a Ollama"))
                .font(Brand.sans(10))
                .foregroundStyle(t.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}

extension Bundle {
    var shortVersion: String { infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev" }
}

// MARK: - piezas comunes

private struct Card<Content: View>: View {
    let theme: Theme
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Brand.radius).fill(theme.card))
            .overlay(RoundedRectangle(cornerRadius: Brand.radius).strokeBorder(theme.line))
    }
}

private struct Eyebrow: View {
    let text: String
    let theme: Theme
    var color: Color?
    var body: some View {
        Text(text)
            .font(Brand.sans(11, .semibold))
            .foregroundStyle(color ?? theme.secondary)
    }
}

/// Interruptor con la marca: rectangular, sin el brillo del de sistema.
private struct BrandSwitch: View {
    let isOn: Bool
    let theme: Theme
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? theme.accent : theme.track)
                    .overlay(Capsule().strokeBorder(isOn ? theme.accent : theme.line))
                    .frame(width: 36, height: 20)
                Circle()
                    .fill(isOn ? theme.onAccent : theme.muted)
                    .frame(width: 14, height: 14)
                    .padding(.horizontal, 3)
            }
            .animation(.easeInOut(duration: 0.15), value: isOn)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private func minutes(_ seconds: TimeInterval) -> Int { max(0, Int(seconds / 60)) }

// MARK: - botón grande

struct PowerHero: View {
    @ObservedObject var ollama: OllamaController
    let theme: Theme
    @State private var pulse = false

    private var t: Theme { theme }

    private var tint: Color {
        switch ollama.power {
        case .on: return t.on
        case .starting, .stopping: return t.warm
        case .off: return t.muted
        case .missing: return t.accent
        }
    }

    private var title: String {
        switch ollama.power {
        case .on: return tr("Encendido")
        case .starting: return tr("Arrancando…")
        case .stopping: return tr("Apagando…")
        case .off: return tr("Apagado")
        case .missing: return tr("Sin Ollama")
        }
    }

    private var detail: String {
        switch ollama.power {
        case .on:
            if let m = ollama.loaded.first { return tr("%@ en memoria", m.name) }
            return tr("Sin modelo en memoria. Se carga con el primer mensaje.")
        case .starting: return tr("Esperando a la API en %@", OllamaAPI.hostLabel)
        case .stopping: return tr("Liberando la memoria del modelo")
        case .off: return tr("Las apps que usan Ollama no responden mientras esté apagado.")
        case .missing: return tr("No lo encuentro en este Mac. Pulsa para descargarlo de ollama.com.")
        }
    }

    private var symbol: String { ollama.power == .missing ? "arrow.down" : "power" }

    var body: some View {
        Card(theme: t) {
            HStack(spacing: 14) {
                Button { ollama.toggle() } label: {
                    ZStack {
                        Circle()
                            .fill(tint.opacity(ollama.power == .off ? 0.08 : 0.14))
                            .frame(width: 72, height: 72)
                            .scaleEffect(ollama.power.isTransition && pulse ? 1.10 : 1)
                        Circle()
                            .strokeBorder(tint, lineWidth: 2)
                            .frame(width: 56, height: 56)
                        Image(systemName: symbol)
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                    .shadow(color: ollama.power == .on ? t.on.opacity(0.30) : .clear, radius: 10)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(ollama.power.isTransition)
                .help(ollama.power == .on ? tr("Apagar Ollama") : ollama.power == .missing ? tr("Descargar Ollama") : tr("Encender Ollama"))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Brand.title(17))
                        .foregroundStyle(ollama.power == .off ? t.secondary : t.fg)
                    Text(detail)
                        .font(Brand.sans(11.5))
                        .foregroundStyle(t.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: ollama.power)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

// MARK: - memoria

struct MemoryCard: View {
    @ObservedObject var ollama: OllamaController
    let theme: Theme
    private var t: Theme { theme }

    private var model: Int64 { ollama.loaded.reduce(0) { $0 + $1.bytes } }
    private var mem: SystemMemory { ollama.memory }

    private var pressure: (String, Color) {
        switch mem.pressure {
        case .normal: return (tr("presión normal"), t.on)
        case .warning: return (tr("presión alta"), t.warm)
        case .critical: return (tr("presión crítica"), t.danger)
        }
    }

    var body: some View {
        Card(theme: t) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Eyebrow(text: tr("Memoria del Mac"), theme: t)
                    Spacer()
                    Circle().fill(pressure.1).frame(width: 6, height: 6)
                    Text(pressure.0)
                        .font(Brand.sans(10.5, .medium))
                        .foregroundStyle(pressure.1)
                }

                GeometryReader { geo in
                    let total = Double(max(mem.total, 1))
                    let usedW = geo.size.width * min(1, Double(mem.used) / total)
                    let modelW = min(usedW, geo.size.width * min(1, Double(model) / total))
                    ZStack(alignment: .leading) {
                        Capsule().fill(t.track)
                        Capsule().fill(t.muted.opacity(0.55)).frame(width: usedW)
                        Capsule()
                            .fill(LinearGradient(colors: [t.accent.opacity(0.75), t.accent],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: modelW > 0 ? max(6, modelW) : 0)
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 8)
                .animation(.easeInOut(duration: 0.4), value: mem.used)

                HStack(spacing: 12) {
                    legend(color: t.accent, label: tr("Modelo"), value: model.memoryGB)
                    legend(color: t.muted.opacity(0.55), label: tr("Resto"), value: max(0, mem.used - model).memoryGB)
                    Spacer(minLength: 4)
                    Text("\(mem.used.memoryGB) / \(mem.total / 1_073_741_824) GB")
                        .font(Brand.mono(10))
                        .foregroundStyle(t.secondary)
                        .fixedSize()
                }

                Rectangle().fill(t.line).frame(height: 1)

                if let m = ollama.loaded.first {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(m.name)
                                .font(Brand.mono(11.5, .medium))
                                .lineLimit(1)
                            Text(idleLine(m))
                                .font(Brand.sans(10.5))
                                .foregroundStyle(t.muted)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button {
                            ollama.unload(m.name)
                        } label: {
                            if ollama.busyModel == m.name {
                                ProgressView().controlSize(.mini)
                            } else {
                                Label(tr("Liberar"), systemImage: "eject").font(Brand.sans(11, .medium))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(ollama.busyModel != nil)
                        .help(tr("Saca el modelo de la memoria sin apagar Ollama"))
                    }
                } else if let released = ollama.autoReleased {
                    Text(tr("Liberado solo a las %@ tras %d min sin uso",
                            released.at.formatted(date: .omitted, time: .shortened),
                            ollama.idleReleaseMinutes))
                        .font(Brand.sans(11))
                        .foregroundStyle(t.muted)
                } else {
                    Text(ollama.power == .on ? tr("Ningún modelo en memoria") : tr("Ollama apagado · 0 GB en uso"))
                        .font(Brand.sans(11))
                        .foregroundStyle(t.muted)
                }
            }
        }
    }

    private func legend(color: Color, label: String, value: String) -> some View {
        HStack(alignment: .center, spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text("\(label) \(value.replacingOccurrences(of: " GB", with: ""))")
                .font(Brand.mono(10))
                .foregroundStyle(t.secondary)
                .fixedSize()
        }
    }

    private func idleLine(_ m: LoadedModel) -> String {
        var parts: [String] = []
        if ollama.idleLimit == nil { parts.append(m.bytes.memoryGB) }
        if let idle = ollama.idleSeconds, idle >= 60 {
            parts.append(tr("sin uso %d min", minutes(idle)))
        }
        if let limit = ollama.idleLimit, let idle = ollama.idleSeconds {
            let left = max(0, limit - idle)
            parts.append(left < 60 ? tr("se libera en <1 min") : tr("se libera en %d min", Int(ceil(left / 60))))
        } else if let ctx = m.context {
            parts.append(tr("contexto %dK", ctx / 1024))
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - modelos

struct ModelList: View {
    @ObservedObject var ollama: OllamaController
    let theme: Theme
    private var t: Theme { theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: tr("Modelos instalados"), theme: t)
                .padding(.horizontal, 2)

            if ollama.installed.isEmpty {
                Card(theme: t) {
                    Text(ollama.power == .on ? tr("No hay modelos. Prueba `ollama pull llama3.2`.") : tr("Enciende Ollama para ver los modelos"))
                        .font(Brand.sans(11))
                        .foregroundStyle(t.muted)
                }
            } else {
                Group {
                    if ollama.installed.count > 6 {
                        ScrollView { rows }.frame(height: 300)
                    } else {
                        rows
                    }
                }
                .background(RoundedRectangle(cornerRadius: Brand.radius).fill(t.card))
                .overlay(RoundedRectangle(cornerRadius: Brand.radius).strokeBorder(t.line))
                .opacity(ollama.power == .on ? 1 : 0.55)
            }
        }
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(Array(ollama.installed.enumerated()), id: \.element.id) { idx, model in
                if idx > 0 { Rectangle().fill(t.line).frame(height: 1) }
                ModelRow(model: model, ollama: ollama, theme: t)
            }
        }
    }
}

struct ModelRow: View {
    let model: InstalledModel
    @ObservedObject var ollama: OllamaController
    let theme: Theme
    @State private var hover = false
    private var t: Theme { theme }

    private var isLoaded: Bool { ollama.loaded.contains { $0.name == model.name } }
    private var isBusy: Bool { ollama.busyModel == model.name }

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(isLoaded ? t.on : t.line)
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 3) {
                Text(model.name)
                    .font(Brand.mono(11.5, isLoaded ? .semibold : .regular))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text([model.bytes.gigabytes, model.quantization].compactMap { $0 }.joined(separator: " · "))
                        .font(Brand.sans(10.5))
                    if model.vision { Chip(text: tr("visión"), theme: t) }
                    if model.tools { Chip(text: tr("herramientas"), theme: t) }
                }
                .foregroundStyle(t.muted)
            }
            Spacer(minLength: 4)

            if isBusy {
                ProgressView().controlSize(.small)
            } else if isLoaded {
                Text(tr("EN USO").lowercased())
                    .font(Brand.sans(10.5, .semibold))
                    .foregroundStyle(t.on)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(t.onSoft))
            } else if hover && ollama.power == .on && ollama.busyModel == nil {
                Button(tr("Cargar")) { ollama.load(model.name) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(t.accent)
                    .help(tr("Carga este modelo en memoria"))
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
    }
}

// MARK: - ajustes

struct SettingsView: View {
    @ObservedObject var ollama: OllamaController
    @ObservedObject var prefs: Prefs
    let theme: Theme
    private var t: Theme { theme }

    static let idleChoices = [0, 5, 15, 30, 60]

    var body: some View {
        VStack(spacing: 10) {
            Card(theme: t) {
                VStack(alignment: .leading, spacing: 9) {
                    Eyebrow(text: tr("Liberar memoria sin uso"), theme: t)
                    HStack(spacing: 0) {
                        ForEach(Self.idleChoices, id: \.self) { m in
                            let selected = ollama.idleReleaseMinutes == m
                            Button { ollama.idleReleaseMinutes = m } label: {
                                Text(m == 0 ? tr("Nunca") : "\(m) min")
                                    .font(Brand.sans(11, selected ? .semibold : .regular))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .foregroundStyle(selected ? t.onAccent : t.secondary)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(selected ? t.accent : Color.clear))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(2)
                    .background(RoundedRectangle(cornerRadius: 8).fill(t.track))

                    Text(tr("Si el modelo no genera nada en ese tiempo, se saca de la memoria. Ollama sigue encendido y lo vuelve a cargar con el siguiente mensaje."))
                        .font(Brand.sans(10.5))
                        .foregroundStyle(t.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Card(theme: t) {
                VStack(spacing: 11) {
                    settingRow(title: tr("Atajo de teclado"),
                               detail: tr("%@ enciende o apaga Ollama desde cualquier app", HotKey.display),
                               isOn: prefs.hotKeyEnabled) { prefs.hotKeyEnabled.toggle() }
                    Rectangle().fill(t.line).frame(height: 1)
                    settingRow(title: tr("Abrir al iniciar sesión"),
                               detail: tr("Siempre a mano en la barra de menús"),
                               isOn: prefs.opensAtLogin) { try? prefs.toggleLogin() }
                }
            }

            Card(theme: t) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tr("Idioma")).font(Brand.sans(12, .semibold))
                        Text(tr("La app se reinicia al cambiarlo"))
                            .font(Brand.sans(10.5))
                            .foregroundStyle(t.muted)
                    }
                    Spacer(minLength: 8)
                    HStack(spacing: 0) {
                        ForEach(Language.allCases, id: \.self) { lang in
                            let selected = prefs.language == lang
                            Button { prefs.setLanguage(lang) } label: {
                                Text(lang.label)
                                    .font(Brand.sans(11, selected ? .semibold : .regular))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .foregroundStyle(selected ? t.onAccent : t.secondary)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(selected ? t.accent : Color.clear))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(2)
                    .background(RoundedRectangle(cornerRadius: 8).fill(t.track))
                }
            }

            HStack {
                Eyebrow(text: "ModelNap \(Bundle.main.shortVersion)", theme: t)
                Spacer()
                Button(tr("Ver el log de Ollama")) { prefs.openLog?() }
                    .buttonStyle(.plain)
                    .font(Brand.sans(11, .medium))
                    .foregroundStyle(t.accent)
                    .disabled(ollama.backend.logURL == nil)
            }
            .padding(.horizontal, 2)
        }
    }

    private func settingRow(title: String, detail: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(Brand.sans(12, .semibold))
                Text(detail)
                    .font(Brand.sans(10.5))
                    .foregroundStyle(t.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            BrandSwitch(isOn: isOn, theme: t, action: action)
        }
    }
}

// MARK: - piezas pequeñas

struct StatePill: View {
    let power: Power
    let theme: Theme

    var body: some View {
        let (text, fg, bg): (String, Color, Color) = {
            switch power {
            case .on: return ("ON", theme.on, theme.onSoft)
            case .starting, .stopping: return ("···", theme.warm, theme.warmSoft)
            case .off: return ("OFF", theme.muted, theme.track)
            case .missing: return ("N/D", theme.accent, theme.accentSoft)
            }
        }()
        HStack(spacing: 5) {
            Circle().fill(fg).frame(width: 6, height: 6)
            Text(text).font(Brand.sans(10.5, .semibold))
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Capsule().fill(bg))
    }
}

struct Chip: View {
    let text: String
    let theme: Theme
    var body: some View {
        Text(text)
            .font(Brand.sans(9.5, .medium))
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(Capsule().fill(theme.track))
    }
}

struct Banner: View {
    let text: String
    let theme: Theme
    let dismiss: () -> Void
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(theme.warm)
            Text(text)
                .font(Brand.sans(11))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            Spacer(minLength: 0)
            Button(action: dismiss) { Image(systemName: "xmark").font(.system(size: 9, weight: .bold)) }
                .buttonStyle(.plain)
                .foregroundStyle(theme.muted)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(theme.warmSoft))
    }
}

struct LoginOffer: View {
    let theme: Theme
    let accept: () -> Void
    let decline: () -> Void
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(tr("¿Abrir al iniciar sesión?"))
                    .font(Brand.sans(11.5, .semibold))
                Text(tr("Siempre a mano en la barra."))
                    .font(Brand.sans(10.5))
                    .foregroundStyle(theme.secondary)
            }
            Spacer()
            Button(tr("No"), action: decline)
                .buttonStyle(.bordered).controlSize(.small)
            Button(tr("Sí"), action: accept)
                .buttonStyle(.borderedProminent).controlSize(.small)
                .tint(theme.accent)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(theme.accentSoft))
    }
}
