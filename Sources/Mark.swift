import AppKit

/// Ícono de la barra de menús y de la app. El estado va en un cuadrado de color
/// —el mismo cuadrado que acompaña a TAVERAS SOLUTIONS en la web—, recortado del
/// dibujo para que se lea sobre cualquier fondo de la barra.
enum Mark {

    enum Dot { case none, on, busy }

    static let ink = NSColor(srgbRed: 0.067, green: 0.067, blue: 0.067, alpha: 1)       // #111111
    static let paper = NSColor(srgbRed: 0.980, green: 0.980, blue: 0.980, alpha: 1)     // #FAFAFA
    static let blue = NSColor(srgbRed: 0.000, green: 0.278, blue: 0.671, alpha: 1)      // #0047AB
    static let teal = NSColor(srgbRed: 0.169, green: 0.702, blue: 0.659, alpha: 1)      // #2BB3A8
    static let warm = NSColor(srgbRed: 0.941, green: 0.404, blue: 0.227, alpha: 1)      // #F0673A

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
            ctx.fill(CGRect(x: c.x - 4.2, y: c.y - 4.2, width: 8.4, height: 8.4))
            ctx.setBlendMode(.normal)
            ctx.setFillColor((dot == .on ? teal : warm).cgColor)
            ctx.fill(CGRect(x: c.x - 2.9, y: c.y - 2.9, width: 5.8, height: 5.8))
            return true
        }
        img.isTemplate = false
        return img
    }

    /// Ícono de la app: cerebro en tinta sobre el papel de la web, con el
    /// cuadrado azul de la marca como piloto de encendido.
    static func drawAppIcon(in ctx: CGContext, px: CGFloat) {
        let r = px * 0.2237
        let squircle = CGRect(x: px * 0.02, y: px * 0.02, width: px * 0.96, height: px * 0.96)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -px * 0.008), blur: px * 0.02,
                      color: NSColor.black.withAlphaComponent(0.25).cgColor)
        ctx.addPath(CGPath(roundedRect: squircle, cornerWidth: r, cornerHeight: r, transform: nil))
        ctx.setFillColor(paper.cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        ctx.addPath(CGPath(roundedRect: squircle.insetBy(dx: px * 0.002, dy: px * 0.002),
                           cornerWidth: r, cornerHeight: r, transform: nil))
        ctx.setStrokeColor(NSColor(white: 0.878, alpha: 1).cgColor)   // #E0E0E0
        ctx.setLineWidth(max(1, px * 0.004))
        ctx.strokePath()

        // Cerebro centrado ópticamente y, pegado a su esquina, el cuadrado azul
        // de la marca con un corte de papel alrededor, igual que en la barra.
        var brain = NSRect.zero
        if let s = symbol("brain.fill", points: px * 0.5, color: ink) {
            let scale = (px * 0.56) / max(s.size.width, s.size.height)
            let w = s.size.width * scale, h = s.size.height * scale
            brain = NSRect(x: (px - w) / 2, y: (px - h) / 2 + px * 0.01, width: w, height: h)
            s.draw(in: brain)
        }

        let d = px * 0.17
        let o = CGPoint(x: brain.maxX - d * 0.62, y: brain.minY - d * 0.28)
        ctx.setFillColor(paper.cgColor)
        ctx.fill(CGRect(x: o.x - d * 0.16, y: o.y - d * 0.16, width: d * 1.32, height: d * 1.32))
        ctx.setFillColor(blue.cgColor)
        ctx.fill(CGRect(x: o.x, y: o.y, width: d, height: d))
    }
}
