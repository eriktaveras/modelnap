import CoreGraphics

/// Logo de ModelNap: un marco redondeado (el modelo) abierto en la esquina superior
/// derecha, con el ojo cerrado dentro y una «z» que se escapa por el hueco.
///
/// Es un dibujo propio. No usa SF Symbols ni se parece a ninguno: su licencia prohíbe
/// usarlos, o glifos parecidos, en íconos de app y logos (por eso se descartaron el
/// cerebro `brain.fill` y una luna con «z», casi idéntica a `moon.zzz.fill`).
///
/// Esta única geometría genera el ícono de la app, la cabecera del panel, el ícono de
/// la barra de menús, el fondo del dmg y los SVG/PNG de la web (Tools/logo).
enum Logo {
    static let canvas: CGFloat = 1024
    /// Radio del squircle de los íconos de macOS (~22,4 %).
    static let iconRadius: CGFloat = 229

    static let frame = CGRect(x: 232, y: 260, width: 560, height: 560)
    static let frameRadius: CGFloat = 150
    static let frameWidth: CGFloat = 56
    static let gapTopX: CGFloat = 640
    static let gapRightY: CGFloat = 440

    static let eyeFrom = CGPoint(x: 392, y: 530)
    static let eyeControl = CGPoint(x: 512, y: 630)
    static let eyeTo = CGPoint(x: 632, y: 530)
    static let eyeWidth: CGFloat = 44
    static let lashes: [(CGPoint, CGPoint)] = [
        (CGPoint(x: 440, y: 562), CGPoint(x: 414, y: 616)),
        (CGPoint(x: 512, y: 580), CGPoint(x: 512, y: 640)),
        (CGPoint(x: 584, y: 562), CGPoint(x: 610, y: 616)),
    ]
    static let lashWidth: CGFloat = 38

    static let z: [CGPoint] = [CGPoint(x: 690, y: 176), CGPoint(x: 812, y: 176),
                               CGPoint(x: 690, y: 298), CGPoint(x: 812, y: 298)]
    static let zWidth: CGFloat = 46

    /// Centro del hueco del marco: ahí va el punto de estado en la barra de menús.
    static let gapCenter = CGPoint(x: 752, y: 300)

    struct Parts: OptionSet {
        let rawValue: Int
        static let lashes = Parts(rawValue: 1 << 0)
        static let z = Parts(rawValue: 1 << 1)
        static let full: Parts = [.lashes, .z]
    }

    /// Dibuja el logo dentro de `rect` en un contexto con la y hacia arriba (el de
    /// Core Graphics por defecto). `weight` engorda los trazos para tamaños pequeños.
    static func draw(in ctx: CGContext, rect: CGRect, color: CGColor, zColor: CGColor? = nil,
                     parts: Parts = .full, weight: CGFloat = 1) {
        let k = min(rect.width, rect.height) / canvas
        ctx.saveGState()
        ctx.translateBy(x: rect.minX, y: rect.maxY)
        ctx.scaleBy(x: k, y: -k)   // a partir de aquí, coordenadas del SVG (y hacia abajo)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        ctx.setStrokeColor(color)
        ctx.setLineWidth(frameWidth * weight)
        ctx.addPath(framePath())
        ctx.strokePath()

        ctx.setLineWidth(eyeWidth * weight)
        ctx.move(to: eyeFrom)
        ctx.addQuadCurve(to: eyeTo, control: eyeControl)
        ctx.strokePath()

        if parts.contains(.lashes) {
            ctx.setLineWidth(lashWidth * weight)
            for (a, b) in lashes {
                ctx.move(to: a)
                ctx.addLine(to: b)
            }
            ctx.strokePath()
        }
        if parts.contains(.z) {
            ctx.setStrokeColor(zColor ?? color)
            ctx.setLineWidth(zWidth * weight)
            ctx.addLines(between: z)
            ctx.strokePath()
        }
        ctx.restoreGState()
    }

    /// Ícono completo: squircle de fondo y logo encima.
    static func drawIcon(in ctx: CGContext, px: CGFloat, background: CGColor, color: CGColor, zColor: CGColor) {
        ctx.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: px, height: px),
                           cornerWidth: px * iconRadius / canvas, cornerHeight: px * iconRadius / canvas, transform: nil))
        ctx.setFillColor(background)
        ctx.fillPath()
        draw(in: ctx, rect: CGRect(x: 0, y: 0, width: px, height: px), color: color, zColor: zColor)
    }

    static func framePath() -> CGPath {
        let l = frame.minX, r = frame.maxX, t = frame.minY, b = frame.maxY
        let p = CGMutablePath()
        p.move(to: CGPoint(x: gapTopX, y: t))
        p.addArc(tangent1End: CGPoint(x: l, y: t), tangent2End: CGPoint(x: l, y: b), radius: frameRadius)
        p.addArc(tangent1End: CGPoint(x: l, y: b), tangent2End: CGPoint(x: r, y: b), radius: frameRadius)
        p.addArc(tangent1End: CGPoint(x: r, y: b), tangent2End: CGPoint(x: r, y: t), radius: frameRadius)
        p.addLine(to: CGPoint(x: r, y: gapRightY))
        return p
    }

    /// SVG equivalente al dibujo de `draw`. `background` añade el squircle del ícono.
    static func svg(color: String, zColor: String? = nil, background: String? = nil) -> String {
        func n(_ v: CGFloat) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v) }
        func stroke(_ c: String, _ w: CGFloat) -> String {
            "fill=\"none\" stroke=\"\(c)\" stroke-width=\"\(n(w))\" stroke-linecap=\"round\" stroke-linejoin=\"round\""
        }
        let l = frame.minX, r = frame.maxX, t = frame.minY, b = frame.maxY, c = frameRadius
        let frameD = "M \(n(gapTopX)) \(n(t)) H \(n(l + c)) A \(n(c)) \(n(c)) 0 0 0 \(n(l)) \(n(t + c)) " +
                     "V \(n(b - c)) A \(n(c)) \(n(c)) 0 0 0 \(n(l + c)) \(n(b)) " +
                     "H \(n(r - c)) A \(n(c)) \(n(c)) 0 0 0 \(n(r)) \(n(b - c)) V \(n(gapRightY))"

        var s = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 1024 1024\" width=\"1024\" height=\"1024\">"
        s += "<title>ModelNap</title>"
        if let background {
            s += "<rect width=\"1024\" height=\"1024\" rx=\"\(n(iconRadius))\" fill=\"\(background)\"/>"
        }
        s += "<path d=\"\(frameD)\" \(stroke(color, frameWidth))/>"
        s += "<path d=\"M \(n(eyeFrom.x)) \(n(eyeFrom.y)) Q \(n(eyeControl.x)) \(n(eyeControl.y)) \(n(eyeTo.x)) \(n(eyeTo.y))\" \(stroke(color, eyeWidth))/>"
        for (a, b2) in lashes {
            s += "<line x1=\"\(n(a.x))\" y1=\"\(n(a.y))\" x2=\"\(n(b2.x))\" y2=\"\(n(b2.y))\" \(stroke(color, lashWidth))/>"
        }
        s += "<polyline points=\"\(z.map { "\(n($0.x)),\(n($0.y))" }.joined(separator: " "))\" \(stroke(zColor ?? color, zWidth))/>"
        return s + "</svg>\n"
    }
}
