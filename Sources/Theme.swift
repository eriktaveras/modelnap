import SwiftUI

/// Identidad verde de la primera versión, la misma familia de tokens que
/// Archivo Drop: verde esmeralda sobre casi negro en oscuro, verde bosque sobre
/// gris verdoso en claro, ámbar para lo que está cambiando.
struct Theme {
    var bg: Color
    var card: Color
    var line: Color
    var fg: Color
    var secondary: Color
    var muted: Color
    var accent: Color
    var accentSoft: Color
    /// Texto encima de un relleno `accent`.
    var onAccent: Color
    var on: Color
    var onSoft: Color
    var warm: Color
    var warmSoft: Color
    var danger: Color
    var track: Color

    static let dark = Theme(
        bg: Color(hex: 0x0B0F0E),
        card: Color(hex: 0x111A16),
        line: Color(hex: 0x22302B),
        fg: Color(hex: 0xE7EFE9),
        secondary: Color(hex: 0x7D938A),
        muted: Color(hex: 0x5C6F66),
        accent: Color(hex: 0x34D399),
        accentSoft: Color(hex: 0x0F2A22),
        onAccent: Color(hex: 0x0B0F0E),
        on: Color(hex: 0x34D399),
        onSoft: Color(hex: 0x0F2A22),
        warm: Color(hex: 0xD9A441),
        warmSoft: Color(hex: 0x2A2210),
        danger: Color(hex: 0xE08A7E),
        track: Color(hex: 0x1A2621)
    )

    static let light = Theme(
        bg: Color(hex: 0xF4F7F5),
        card: Color(hex: 0xFFFFFF),
        line: Color(hex: 0xDFE8E3),
        fg: Color(hex: 0x0F1614),
        secondary: Color(hex: 0x5C6B64),
        muted: Color(hex: 0x8A9992),
        accent: Color(hex: 0x047857),
        accentSoft: Color(hex: 0xE6F4EE),
        onAccent: Color(hex: 0xFFFFFF),
        on: Color(hex: 0x047857),
        onSoft: Color(hex: 0xE6F4EE),
        warm: Color(hex: 0x8A6212),
        warmSoft: Color(hex: 0xF7EEDB),
        danger: Color(hex: 0xA4402F),
        track: Color(hex: 0xE4ECE7)
    )

    static func of(_ scheme: ColorScheme) -> Theme { scheme == .dark ? .dark : .light }
}

/// Tipografía y formas. Fuentes del sistema (SF Pro y SF Mono), como la primera versión.
enum Brand {
    static let name = "Taveras Solutions"
    static let radius: CGFloat = 12

    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold) }
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
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
