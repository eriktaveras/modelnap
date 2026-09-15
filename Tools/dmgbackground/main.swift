import AppKit

// Fondo de la ventana del .dmg (compilar junto a Sources/Logo.swift) (660x440 pt, @1x y @2x), con la identidad verde
// de la app. Los íconos los coloca Finder encima: app en (170, 200)
// y Aplicaciones en (490, 200), coordenadas desde arriba a la izquierda.
//   dmgbackground <salida-sin-extension> <version>

let args = CommandLine.arguments
guard args.count > 2 else {
    FileHandle.standardError.write(Data("uso: dmgbackground <salida-sin-extension> <version>\n".utf8))
    exit(1)
}
let outBase = args[1]
let version = args[2]

func font(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont { .systemFont(ofSize: size, weight: weight) }
func mono(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont { .monospacedSystemFont(ofSize: size, weight: weight) }

func hex(_ v: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255, alpha: a)
}

// Paleta clara de la identidad verde (la de la primera versión y Archivo Drop).
let W: CGFloat = 660, H: CGFloat = 440
let paper = hex(0xF4F7F5), card = hex(0xFFFFFF), line = hex(0xDFE8E3)
let ink = hex(0x0F1614), secondary = hex(0x5C6B64), muted = hex(0x8A9992)
let green = hex(0x047857), greenSoft = hex(0xE6F4EE)

func text(_ s: String, _ f: NSFont, _ c: NSColor, at p: CGPoint, kern: CGFloat = 0) {
    NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: c, .kern: kern]).draw(at: p)
}

func paragraph(_ s: NSAttributedString, in r: CGRect) {
    s.draw(with: r, options: [.usesLineFragmentOrigin])
}

func render(scale: CGFloat) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W * scale), pixelsHigh: Int(H * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H)
    let g = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    // Contexto volteado: y crece hacia abajo, como en Finder.
    NSGraphicsContext.current = NSGraphicsContext(cgContext: g.cgContext, flipped: true)
    let ctx = g.cgContext
    ctx.translateBy(x: 0, y: H)
    ctx.scaleBy(x: 1, y: -1)

    paper.setFill()
    CGRect(x: 0, y: 0, width: W, height: H).fill()

    // Cabecera: logo, nombre y versión.
    if let cg = NSGraphicsContext.current?.cgContext {
        // El contexto está volteado (y hacia abajo); Logo dibuja con y hacia arriba.
        cg.saveGState()
        cg.translateBy(x: 0, y: 66)
        cg.scaleBy(x: 1, y: -1)
        Logo.draw(in: cg, rect: CGRect(x: 24, y: 0, width: 42, height: 42), color: green.cgColor, weight: 1.1)
        cg.restoreGState()
    }
    text("ModelNap", font(24, weight: .bold), ink, at: CGPoint(x: 66, y: 30))
    text(tr("Deja dormir a tus modelos locales y recupera la memoria del Mac."), font(13), secondary, at: CGPoint(x: 67, y: 62))
    text("Let idle local LLMs sleep. Get your Mac's memory back.", font(11), muted, at: CGPoint(x: 67, y: 81))

    let v = "v\(version)"
    let vf = mono(11)
    let vw = (v as NSString).size(withAttributes: [.font: vf]).width
    let pill = CGRect(x: W - 32 - vw - 16, y: 36, width: vw + 16, height: 20)
    greenSoft.setFill()
    NSBezierPath(roundedRect: pill, xRadius: 10, yRadius: 10).fill()
    text(v, vf, green, at: CGPoint(x: pill.minX + 8, y: pill.minY + 3))

    // Flecha entre la app y Aplicaciones.
    let y: CGFloat = 200
    green.setStroke()
    let arrow = NSBezierPath()
    arrow.lineWidth = 2
    arrow.lineCapStyle = .round
    arrow.move(to: CGPoint(x: 262, y: y))
    arrow.line(to: CGPoint(x: 394, y: y))
    arrow.stroke()
    let head = NSBezierPath()
    head.move(to: CGPoint(x: 398, y: y))
    head.line(to: CGPoint(x: 387, y: y - 6.5))
    head.line(to: CGPoint(x: 387, y: y + 6.5))
    head.close()
    green.setFill()
    head.fill()
    let drag = tr("arrastra")
    let df = font(11, weight: .semibold)
    let dw = (drag as NSString).size(withAttributes: [.font: df]).width
    text(drag, df, green, at: CGPoint(x: 330 - dw / 2, y: y - 26))

    // Qué hacer después de arrastrar.
    let box = CGRect(x: 32, y: 318, width: W - 64, height: 84)
    card.setFill()
    let boxPath = NSBezierPath(roundedRect: box, xRadius: 12, yRadius: 12)
    boxPath.fill()
    line.setStroke()
    let border = NSBezierPath(roundedRect: box.insetBy(dx: 0.5, dy: 0.5), xRadius: 12, yRadius: 12)
    border.lineWidth = 1
    border.stroke()

    let dot = CGRect(x: box.minX + 18, y: box.minY + 19, width: 8, height: 8)
    green.setFill()
    NSBezierPath(ovalIn: dot).fill()
    text(tr("Después"), font(12, weight: .semibold), ink, at: CGPoint(x: box.minX + 34, y: box.minY + 14))

    let body = NSMutableAttributedString()
    let sans = font(12)
    let bold = font(12, weight: .semibold)
    let style = NSMutableParagraphStyle()
    style.lineSpacing = 2
    body.append(NSAttributedString(string: tr("Abre la app desde Aplicaciones. Vive en la "),
                                   attributes: [.font: sans, .foregroundColor: secondary]))
    body.append(NSAttributedString(string: tr("barra de menús, arriba a la derecha"),
                                   attributes: [.font: bold, .foregroundColor: ink]))
    body.append(NSAttributedString(string: tr(": el logo de ModelNap con un punto verde. Clic para abrir el panel."),
                                   attributes: [.font: sans, .foregroundColor: secondary]))
    body.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: body.length))
    paragraph(body, in: CGRect(x: box.minX + 34, y: box.minY + 34, width: box.width - 52, height: 44))

    // Pie: crédito y aviso.
    green.setFill()
    NSBezierPath(ovalIn: CGRect(x: 32, y: 419, width: 6, height: 6)).fill()
    text("Taveras Solutions", font(10.5, weight: .semibold), secondary, at: CGPoint(x: 43, y: 414))
    let legal = tr("modelnap.com · Firmada y notarizada por Apple · No afiliado a Ollama")
    let lf = font(10)
    let lw = (legal as NSString).size(withAttributes: [.font: lf]).width
    text(legal, lf, muted, at: CGPoint(x: W - 32 - lw, y: 415))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// El dmg se ve en el idioma de quien lo abre, pero la imagen es una sola: va en
// español (idioma base) con la línea en inglés debajo del subtítulo.
func tr(_ s: String) -> String { s }

try render(scale: 1).write(to: URL(fileURLWithPath: "\(outBase).png"))
try render(scale: 2).write(to: URL(fileURLWithPath: "\(outBase)@2x.png"))
print("fondo: \(outBase).png y @2x")
