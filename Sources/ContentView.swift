import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var ollama: OllamaController
    @ObservedObject var prefs: Prefs
    @Environment(\.colorScheme) private var scheme

    private var t: Theme { Theme.of(scheme) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(t.line).frame(height: 1)

            VStack(spacing: 10) {
                PowerHero(ollama: ollama, theme: t)
                if let error = ollama.error {
                    Banner(text: error, theme: t) { ollama.error = nil }
                }
                if prefs.shouldOfferLogin {
                    LoginOffer(theme: t, accept: { prefs.answerLogin(true) }, decline: { prefs.answerLogin(false) })
                }
                if ollama.power != .missing {
                    MemoryCard(ollama: ollama, theme: t)
                    ModelList(ollama: ollama, theme: t)
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
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Interruptor Ollama")
                    .font(Brand.sans(14, .semibold))
                Text(subtitle)
                    .font(Brand.mono(10))
                    .foregroundStyle(t.muted)
                    .lineLimit(1)
            }
            Spacer()
            StatePill(power: ollama.power, theme: t)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var subtitle: String {
        if let v = ollama.version { return "v\(v) · \(ollama.backend.summary)" }
        return ollama.backend.summary
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button { NSWorkspace.shared.open(Paths.brand) } label: {
                HStack(spacing: 6) {
                    Rectangle().fill(t.accent).frame(width: 6, height: 6)
                    Text("TAVERAS SOLUTIONS")
                        .font(Brand.mono(9.5, .semibold))
                        .tracking(-0.2)
                        .foregroundStyle(t.fg)
                }
            }
            .buttonStyle(.plain)
            .help("taverassolutions.com")
            Spacer()
            Text("No afiliado a Ollama")
                .font(Brand.mono(9))
                .foregroundStyle(t.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
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
    var body: some View {
        Text(text.uppercased())
            .font(Brand.mono(9.5, .medium))
            .tracking(1.2)
            .foregroundStyle(theme.muted)
    }
}

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
        case .on: return "Encendido"
        case .starting: return "Arrancando…"
        case .stopping: return "Apagando…"
        case .off: return "Apagado"
        case .missing: return "Sin Ollama"
        }
    }

    private var detail: String {
        switch ollama.power {
        case .on:
            if let m = ollama.loaded.first { return "\(m.name) en memoria" }
            return "Sin modelo en memoria. Se carga con el primer mensaje."
        case .starting: return "Esperando a la API en \(OllamaAPI.hostLabel)"
        case .stopping: return "Liberando la memoria del modelo"
        case .off: return "Las apps que usan Ollama no responden mientras esté apagado."
        case .missing: return "No lo encuentro en este Mac. Pulsa para descargarlo de ollama.com."
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
                .help(ollama.power == .on ? "Apagar Ollama" : ollama.power == .missing ? "Descargar Ollama" : "Encender Ollama")

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Brand.serif(30))
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

    private var used: Int64 { ollama.loaded.reduce(0) { $0 + $1.bytes } }

    var body: some View {
        Card(theme: t) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Eyebrow(text: "Memoria", theme: t)
                    Spacer()
                    Text("\(used.gigabytes) / \(ollama.totalMemory / 1_073_741_824) GB")
                        .font(Brand.mono(10.5))
                        .foregroundStyle(t.secondary)
                }

                GeometryReader { geo in
                    let frac = min(1, Double(used) / Double(max(ollama.totalMemory, 1)))
                    ZStack(alignment: .leading) {
                        Rectangle().fill(t.track)
                        Rectangle()
                            .fill(t.accent)
                            .frame(width: max(frac > 0 ? 4 : 0, geo.size.width * frac))
                    }
                }
                .frame(height: 6)
                .animation(.easeInOut(duration: 0.4), value: used)

                if let m = ollama.loaded.first {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(m.name)
                                .font(Brand.mono(11.5, .medium))
                                .lineLimit(1)
                            Text([m.bytes.gigabytes, m.context.map { "contexto \($0 / 1024)K" }]
                                    .compactMap { $0 }.joined(separator: " · "))
                                .font(Brand.sans(10.5))
                                .foregroundStyle(t.muted)
                        }
                        Spacer()
                        Button {
                            ollama.unload(m.name)
                        } label: {
                            if ollama.busyModel == m.name {
                                ProgressView().controlSize(.mini)
                            } else {
                                Label("Liberar", systemImage: "eject").font(Brand.sans(11, .medium))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(ollama.busyModel != nil)
                        .help("Saca el modelo de la memoria sin apagar Ollama")
                    }
                } else {
                    Text(ollama.power == .on ? "Ningún modelo en memoria" : "Ollama apagado · 0 GB en uso")
                        .font(Brand.sans(11))
                        .foregroundStyle(t.muted)
                }
            }
        }
    }
}

// MARK: - modelos

struct ModelList: View {
    @ObservedObject var ollama: OllamaController
    let theme: Theme
    private var t: Theme { theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: "Modelos instalados", theme: t)
                .padding(.horizontal, 2)

            if ollama.installed.isEmpty {
                Card(theme: t) {
                    Text(ollama.power == .on ? "No hay modelos. Prueba `ollama pull llama3.2`." : "Enciende Ollama para ver los modelos")
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
}

private extension ModelList {
    var rows: some View {
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
            Rectangle()
                .fill(isLoaded ? t.on : t.line)
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 3) {
                Text(model.name)
                    .font(Brand.mono(11.5, isLoaded ? .semibold : .regular))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text([model.bytes.gigabytes, model.quantization].compactMap { $0 }.joined(separator: " · "))
                        .font(Brand.sans(10.5))
                    if model.vision { Chip(text: "visión", theme: t) }
                    if model.tools { Chip(text: "herramientas", theme: t) }
                }
                .foregroundStyle(t.muted)
            }
            Spacer(minLength: 4)

            if isBusy {
                ProgressView().controlSize(.small)
            } else if isLoaded {
                Text("EN USO")
                    .font(Brand.mono(9, .bold))
                    .tracking(0.8)
                    .foregroundStyle(t.on)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Rectangle().fill(t.onSoft))
            } else if hover && ollama.power == .on && ollama.busyModel == nil {
                Button("Cargar") { ollama.load(model.name) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(t.accent)
                    .help("Carga este modelo en memoria")
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
    }
}

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
            Rectangle().fill(fg).frame(width: 6, height: 6)
            Text(text).font(Brand.mono(10, .bold))
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Rectangle().fill(bg))
    }
}

struct Chip: View {
    let text: String
    let theme: Theme
    var body: some View {
        Text(text)
            .font(Brand.mono(9))
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(Rectangle().fill(theme.track))
    }
}

struct Banner: View {
    let text: String
    let theme: Theme
    let dismiss: () -> Void
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Rectangle().fill(theme.warm).frame(width: 2)
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
        .background(Rectangle().fill(theme.warmSoft))
    }
}

struct LoginOffer: View {
    let theme: Theme
    let accept: () -> Void
    let decline: () -> Void
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("¿Abrir al iniciar sesión?")
                    .font(Brand.sans(11.5, .semibold))
                Text("Siempre a mano en la barra.")
                    .font(Brand.sans(10.5))
                    .foregroundStyle(theme.secondary)
            }
            Spacer()
            Button("No", action: decline)
                .buttonStyle(.bordered).controlSize(.small)
            Button("Sí", action: accept)
                .buttonStyle(.borderedProminent).controlSize(.small)
                .tint(theme.accent)
        }
        .padding(10)
        .background(Rectangle().fill(theme.accentSoft))
    }
}
