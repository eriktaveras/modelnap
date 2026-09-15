import SwiftUI
import CoreText

/// Identidad de Taveras Solutions tal como está en taverassolutions.com
/// («Terminal Luxe»): tinta casi negra sobre #FAFAFA, azul técnico, teal para
/// métricas y naranja arquitectónico de alerta. La web no tiene modo oscuro;
/// la variante oscura invierte la tinta y aclara los acentos para que aguanten
/// el contraste.
struct Theme {
    var bg: Color
    var card: Color
    var line: Color
    var fg: Color
    var secondary: Color
    var muted: Color
    var accent: Color
    var accentSoft: Color
    var on: Color
    var onSoft: Color
    var warm: Color
    var warmSoft: Color
    var track: Color

    static let light = Theme(
        bg: Color(hex: 0xFAFAFA),
        card: Color(hex: 0xFFFFFF),
        line: Color(hex: 0xE0E0E0),
        fg: Color(hex: 0x111111),
        secondary: Color(hex: 0x444444),
        muted: Color(hex: 0x888888),
        accent: Color(hex: 0x0047AB),
        accentSoft: Color(hex: 0x0047AB, opacity: 0.08),
        on: Color(hex: 0x008080),
        onSoft: Color(hex: 0x008080, opacity: 0.10),
        warm: Color(hex: 0xD34418),
        warmSoft: Color(hex: 0xD34418, opacity: 0.09),
        track: Color(hex: 0xF0F0F0)
    )

    static let dark = Theme(
        bg: Color(hex: 0x0F0F0F),
        card: Color(hex: 0x171717),
        line: Color(hex: 0x2A2A2A),
        fg: Color(hex: 0xEDEDED),
        secondary: Color(hex: 0xB8B8B8),
        muted: Color(hex: 0x7A7A7A),
        accent: Color(hex: 0x5C8FE6),
        accentSoft: Color(hex: 0x5C8FE6, opacity: 0.14),
        on: Color(hex: 0x2BB3A8),
        onSoft: Color(hex: 0x2BB3A8, opacity: 0.14),
        warm: Color(hex: 0xF0673A),
        warmSoft: Color(hex: 0xF0673A, opacity: 0.14),
        track: Color(hex: 0x222222)
    )

    static func of(_ scheme: ColorScheme) -> Theme { scheme == .dark ? .dark : .light }
}

/// Tipografías de la web, empaquetadas en Resources/Fonts (licencia OFL).
enum Brand {
    static let name = "Taveras Solutions"
    static let radius: CGFloat = 3

    static func serif(_ size: CGFloat) -> Font { .custom("Instrument Serif", size: size) }
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("DM Sans", size: size).weight(weight)
    }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("JetBrains Mono", size: size).weight(weight)
    }

    /// Registra las fuentes del bundle para este proceso. Si no están (build a
    /// medias), SwiftUI cae en la fuente del sistema y la app sigue funcionando.
    static func registerFonts(in resources: URL? = Bundle.main.resourceURL) {
        guard let dir = resources?.appendingPathComponent("Fonts"),
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        let fonts = files.filter { ["ttf", "otf"].contains($0.pathExtension.lowercased()) }
        CTFontManagerRegisterFontURLs(fonts as CFArray, .process, false, nil)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}
