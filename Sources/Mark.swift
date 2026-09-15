import AppKit

/// Ícono de la barra de menús y de la app: el cerebro de SF Symbols con un
/// punto de estado redondo, recortado del dibujo para que se lea sobre
/// cualquier fondo de la barra.
enum Mark {

    enum Dot { case none, on, busy }

    static let green = NSColor(srgbRed: 0.204, green: 0.827, blue: 0.600, alpha: 1)   // #34D399
    static let amber = NSColor(srgbRed: 0.851, green: 0.643, blue: 0.255, alpha: 1)   // #D9A441
    static let night = NSColor(srgbRed: 0.043, green: 0.059, blue: 0.055, alpha: 1)   // #0B0F0E

    private static func symbol(_ name: String, points: CGFloat, color: NSColor) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: points, weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        return NSImage(systemSymbolName: name, accessibilityDescription: "Ollama")?
            .withSymbolConfiguration(config)
    }

    /// El manejador de dibujo se evalúa con la apariencia de la barra en cada
    /// repintado, así que `labelColor` sale blanco o negro según toque.
    static func statusImage(dot: Dot, dimmed: Bool) -> NSImage {
        let size = NSSize(width: 22, height: 18)
        let img = NSImage(size: size, flipped: false) { rect in
            let color: NSColor = dimmed ? .secondaryLabelColor : .labelColor
            if let s = symbol(dimmed ? "brain" : "brain.fill", points: 14, color: color) {
                let r = NSRect(x: (rect.width - s.size.width) / 2 - 1,
                               y: (rect.height - s.size.height) / 2,
                               width: s.size.width, height: s.size.height)
                s.draw(in: r)
            }
            guard dot != .none, let ctx = NSGraphicsContext.current?.cgContext else { return true }
            let c = CGPoint(x: rect.maxX - 4, y: 4)
            ctx.setBlendMode(.clear)
            ctx.fillEllipse(in: CGRect(x: c.x - 4.2, y: c.y - 4.2, width: 8.4, height: 8.4))
            ctx.setBlendMode(.normal)
            ctx.setFillColor((dot == .on ? green : amber).cgColor)
            ctx.fillEllipse(in: CGRect(x: c.x - 2.8, y: c.y - 2.8, width: 5.6, height: 5.6))
            return true
        }
        img.isTemplate = false
        return img
    }

    /// Ícono de la app: cerebro verde sobre fondo casi negro, con el punto de encendido.
    static func drawAppIcon(in ctx: CGContext, px: CGFloat) {
        let r = px * 0.2237
        ctx.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: px, height: px),
                           cornerWidth: r, cornerHeight: r, transform: nil))
        ctx.setFillColor(NSColor(srgbRed: 0.063, green: 0.075, blue: 0.094, alpha: 1).cgColor)
        ctx.fillPath()

        guard let s = symbol("brain.fill", points: px * 0.5, color: green) else { return }
        let scale = (px * 0.56) / max(s.size.width, s.size.height)
        let w = s.size.width * scale, h = s.size.height * scale
        s.draw(in: NSRect(x: (px - w) / 2, y: (px - h) / 2 + px * 0.02, width: w, height: h))

        let d = px * 0.17
        let o = CGPoint(x: px * 0.70, y: px * 0.13)
        ctx.setFillColor(NSColor(srgbRed: 0.063, green: 0.075, blue: 0.094, alpha: 1).cgColor)
        ctx.fillEllipse(in: CGRect(x: o.x - d * 0.2, y: o.y - d * 0.2, width: d * 1.4, height: d * 1.4))
        ctx.setFillColor(green.cgColor)
        ctx.fillEllipse(in: CGRect(x: o.x, y: o.y, width: d, height: d))
    }
}
