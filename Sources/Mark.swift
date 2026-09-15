import AppKit

/// Ícono de la barra de menús, de la cabecera y de la app, todos a partir de `Logo`.
enum Mark {

    enum Dot { case none, on, busy }

    static let green = NSColor(srgbRed: 0.204, green: 0.827, blue: 0.600, alpha: 1)   // #34D399
    static let mint = NSColor(srgbRed: 0.655, green: 0.953, blue: 0.816, alpha: 1)    // #A7F3D0
    static let amber = NSColor(srgbRed: 0.851, green: 0.643, blue: 0.255, alpha: 1)   // #D9A441
    static let iconBackground = NSColor(srgbRed: 0.063, green: 0.075, blue: 0.094, alpha: 1)  // #101318

    /// Barra de menús: marco y ojo con pestañas (sin ellas parece una sonrisa), sin la «z», con
    /// el punto de estado en el hueco del marco. El manejador de dibujo se evalúa con
    /// la apariencia de la barra, así que `labelColor` sale blanco o negro según toque.
    static func statusImage(dot: Dot, dimmed: Bool) -> NSImage {
        let size = NSSize(width: 22, height: 18)
        let img = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let color: NSColor = dimmed ? .secondaryLabelColor : .labelColor
            let box = CGRect(x: (rect.width - 20) / 2, y: (rect.height - 20) / 2, width: 20, height: 20)
            Logo.draw(in: ctx, rect: box, color: color.cgColor, parts: [.lashes], weight: 1.45)

            guard dot != .none else { return true }
            let k = box.width / Logo.canvas
            let c = CGPoint(x: box.minX + Logo.gapCenter.x * k, y: box.maxY - Logo.gapCenter.y * k)
            ctx.setFillColor((dot == .on ? green : amber).cgColor)
            ctx.fillEllipse(in: CGRect(x: c.x - 3, y: c.y - 3, width: 6, height: 6))
            return true
        }
        img.isTemplate = false
        return img
    }

    /// Logo suelto para la cabecera del panel.
    static func logoImage(points: CGFloat, color: NSColor, zColor: NSColor? = nil) -> NSImage {
        NSImage(size: NSSize(width: points, height: points), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            Logo.draw(in: ctx, rect: rect, color: color.cgColor, zColor: zColor?.cgColor,
                      weight: points < 40 ? 1.25 : 1)
            return true
        }
    }

    /// Ícono de la app: logo verde sobre fondo casi negro.
    static func drawAppIcon(in ctx: CGContext, px: CGFloat) {
        Logo.drawIcon(in: ctx, px: px, background: iconBackground.cgColor, color: green.cgColor, zColor: mint.cgColor)
    }
}
