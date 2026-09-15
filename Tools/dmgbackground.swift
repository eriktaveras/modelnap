import AppKit
import CoreText

// Fondo de la ventana del .dmg (660x440 pt, @1x y @2x), con la identidad de
// taverassolutions.com. Los íconos los coloca Finder encima: app en (170, 200)
// y Aplicaciones en (490, 200), coordenadas desde arriba a la izquierda.
//   dmgbackground <fonts-dir> <salida-sin-extension> <version>

let args = CommandLine.arguments
guard args.count > 3 else {
    FileHandle.standardError.write(Data("uso: dmgbackground <fonts> <salida> <version>\n".utf8))
    exit(1)
}
let fontsDir = URL(fileURLWithPath: args[1])
let outBase = args[2]
let version = args[3]

let fontFiles = (try? FileManager.default.contentsOfDirectory(at: fontsDir, includingPropertiesForKeys: nil)) ?? []
CTFontManagerRegisterFontURLs(fontFiles.filter { $0.pathExtension == "ttf" } as CFArray, .process, false, nil)

func font(_ family: String, _ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
    let desc = NSFontDescriptor(fontAttributes: [
        .family: family,
        .traits: [NSFontDescriptor.TraitKey.weight: weight],
    ])
    return NSFont(descriptor: desc, size: size) ?? .systemFont(ofSize: size, weight: weight)
}

func hex(_ v: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255, alpha: a)
}

let W: CGFloat = 660, H: CGFloat = 440
let paper = hex(0xFAFAFA), card = hex(0xFFFFFF), line = hex(0xE0E0E0)
let ink = hex(0x111111), secondary = hex(0x444444), muted = hex(0x888888)
let blue = hex(0x0047AB), warm = hex(0xD34418)

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

    // Retícula técnica muy tenue, como el fondo de la web.
    hex(0x111111, 0.035).setFill()
    stride(from: CGFloat(20), to: W, by: 20).forEach { x in
        stride(from: CGFloat(20), to: H, by: 20).forEach { y in
            CGRect(x: x, y: y, width: 1, height: 1).fill()
        }
    }

    // Cabecera: logotipo y versión.
    blue.setFill()
    CGRect(x: 32, y: 30, width: 8, height: 8).fill()
    text("TAVERAS SOLUTIONS", font("JetBrains Mono", 11, weight: .semibold), ink, at: CGPoint(x: 47, y: 26), kern: -0.2)
    let v = "V\(version)"
    let vf = font("JetBrains Mono", 10)
    let vw = (v as NSString).size(withAttributes: [.font: vf, .kern: 1.2]).width
    text(v, vf, muted, at: CGPoint(x: W - 32 - vw, y: 27), kern: 1.2)

    line.setFill()
    CGRect(x: 32, y: 52, width: W - 64, height: 1).fill()

    // Título.
    text("Interruptor Ollama", font("Instrument Serif", 34), ink, at: CGPoint(x: 32, y: 62))
    text("Enciende y apaga Ollama desde la barra de menús.", font("DM Sans", 13), secondary,
         at: CGPoint(x: 34, y: 112))

    // Flecha entre la app y Aplicaciones.
    let y: CGFloat = 200
    ink.setStroke()
    let arrow = NSBezierPath()
    arrow.lineWidth = 1.5
    arrow.move(to: CGPoint(x: 262, y: y))
    arrow.line(to: CGPoint(x: 396, y: y))
    arrow.stroke()
    let head = NSBezierPath()
    head.move(to: CGPoint(x: 398, y: y))
    head.line(to: CGPoint(x: 388, y: y - 6))
    head.line(to: CGPoint(x: 388, y: y + 6))
    head.close()
    ink.setFill()
    head.fill()
    let drag = "ARRASTRA"
    let df = font("JetBrains Mono", 10, weight: .medium)
    let dw = (drag as NSString).size(withAttributes: [.font: df, .kern: 1.6]).width
    text(drag, df, muted, at: CGPoint(x: 330 - dw / 2, y: y - 24), kern: 1.6)

    // Qué hacer después de arrastrar.
    let box = CGRect(x: 32, y: 318, width: W - 64, height: 88)
    card.setFill()
    NSBezierPath(rect: box).fill()
    line.setStroke()
    let border = NSBezierPath(rect: box.insetBy(dx: 0.5, dy: 0.5))
    border.lineWidth = 1
    border.stroke()
    blue.setFill()
    CGRect(x: box.minX, y: box.minY, width: 2, height: box.height).fill()

    text("DESPUÉS", font("JetBrains Mono", 9.5, weight: .medium), blue,
         at: CGPoint(x: box.minX + 18, y: box.minY + 14), kern: 1.4)

    let body = NSMutableAttributedString()
    let sans = font("DM Sans", 12)
    let bold = font("DM Sans", 12, weight: .semibold)
    let style = NSMutableParagraphStyle()
    style.lineSpacing = 2
    body.append(NSAttributedString(string: "Abre la app desde Aplicaciones. Vive en la ",
                                   attributes: [.font: sans, .foregroundColor: secondary]))
    body.append(NSAttributedString(string: "barra de menús, arriba a la derecha",
                                   attributes: [.font: bold, .foregroundColor: ink]))
    body.append(NSAttributedString(string: ": un cerebro con un cuadrado de color. Clic para abrir el panel.",
                                   attributes: [.font: sans, .foregroundColor: secondary]))
    body.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: body.length))
    paragraph(body, in: CGRect(x: box.minX + 18, y: box.minY + 33, width: box.width - 36, height: 50))

    text("Firmada y notarizada por Apple · No afiliado a Ollama · taverassolutions.com",
         font("JetBrains Mono", 9), muted, at: CGPoint(x: 32, y: 416))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try render(scale: 1).write(to: URL(fileURLWithPath: "\(outBase).png"))
try render(scale: 2).write(to: URL(fileURLWithPath: "\(outBase)@2x.png"))
print("fondo: \(outBase).png y @2x")
