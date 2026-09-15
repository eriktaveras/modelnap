import AppKit

// Imágenes del README a partir de las capturas del panel (`--snapshot … demo`).
//   readme-images <capturas-dir> <salida-dir> <dmg-fondo@2x.png> <app>
// Espera en <capturas-dir>: panel-<light|dark>.png, settings-<light|dark>.png y panel-en-light.png

let args = CommandLine.arguments
guard args.count > 4 else {
    FileHandle.standardError.write(Data("uso: readme-images <capturas> <salida> <dmg-fondo@2x.png> <app>\n".utf8))
    exit(1)
}
let shots = URL(fileURLWithPath: args[1])
let out = URL(fileURLWithPath: args[2])
let dmgBackground = args[3]
let appPath = URL(fileURLWithPath: args[4]).standardizedFileURL.path

func hex(_ v: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255, alpha: a)
}

/// Lienzo en píxeles con coordenadas en puntos (@2x) y origen arriba a la izquierda.
func canvas(_ w: CGFloat, _ h: CGFloat, dark: Bool? = nil, _ draw: (CGContext) -> Void) -> Data {
    let scale: CGFloat = 2
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(w * scale), pixelsHigh: Int(h * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: w, height: h)
    let g = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: g.cgContext, flipped: true)
    let ctx = g.cgContext
    ctx.translateBy(x: 0, y: h)
    ctx.scaleBy(x: 1, y: -1)
    let appearance = dark.map { NSAppearance(named: $0 ? .darkAqua : .aqua)! }
    if let appearance {
        appearance.performAsCurrentDrawingAppearance { draw(ctx) }
    } else {
        draw(ctx)
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

func image(_ name: String) -> NSImage {
    guard let img = NSImage(contentsOf: shots.appendingPathComponent(name)) else {
        FileHandle.standardError.write(Data("falta \(name)\n".utf8)); exit(1)
    }
    return img
}

/// Panel con esquinas del popover de macOS, borde fino y sombra suave.
func drawPanel(_ img: NSImage, at origin: CGPoint, width: CGFloat, dark: Bool, in ctx: CGContext) {
    let size = CGSize(width: width, height: width * img.size.height / img.size.width)
    let rect = CGRect(origin: origin, size: size)
    let path = NSBezierPath(roundedRect: rect, xRadius: 14, yRadius: 14)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 18), blur: 40,
                  color: NSColor.black.withAlphaComponent(dark ? 0.55 : 0.18).cgColor)
    (dark ? hex(0x0B0F0E) : hex(0xF4F7F5)).setFill()
    path.fill()
    ctx.restoreGState()
    ctx.saveGState()
    path.addClip()
    img.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    ctx.restoreGState()
    (dark ? hex(0xFFFFFF, 0.08) : hex(0x000000, 0.08)).setStroke()
    let border = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 14, yRadius: 14)
    border.lineWidth = 1
    border.stroke()
}

func gradient(_ ctx: CGContext, _ rect: CGRect, _ top: NSColor, _ bottom: NSColor) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                       colors: [top.cgColor, bottom.cgColor] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: rect.minX, y: rect.minY), end: CGPoint(x: rect.maxX, y: rect.maxY), options: [])
}

func text(_ s: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor, at p: CGPoint, mono: Bool = false) {
    let font = mono ? NSFont.monospacedSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight)
    NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color]).draw(at: p)
}

func textWidth(_ s: String, size: CGFloat, weight: NSFont.Weight = .regular) -> CGFloat {
    (s as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight)]).width
}

/// Franja de barra de menús con el ícono de la app resaltado.
func menuBar(_ ctx: CGContext, width: CGFloat, dark: Bool, iconX: CGFloat) {
    let bar = CGRect(x: 0, y: 0, width: width, height: 30)
    (dark ? hex(0x1C1F1E, 0.92) : hex(0xFFFFFF, 0.75)).setFill()
    bar.fill()
    (dark ? hex(0xFFFFFF, 0.06) : hex(0x000000, 0.06)).setFill()
    CGRect(x: 0, y: 29, width: width, height: 1).fill()

    let fg: NSColor = dark ? hex(0xF2F2F2) : hex(0x1D1D1F)
    let right = ["9:41", "battery.75percent", "wifi"]
    var x = width - 18
    for item in right {
        if item.contains(":") {
            let w = textWidth(item, size: 13, weight: .medium)
            x -= w
            text(item, size: 13, weight: .medium, color: fg, at: CGPoint(x: x, y: 6))
        } else if let sym = NSImage(systemSymbolName: item, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .regular).applying(.init(paletteColors: [fg]))) {
            x -= sym.size.width
            sym.draw(in: CGRect(x: x, y: 15 - sym.size.height / 2, width: sym.size.width, height: sym.size.height),
                     from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
        x -= 18
    }

    let highlight = CGRect(x: iconX - 5, y: 4, width: 32, height: 22)
    (dark ? hex(0xFFFFFF, 0.14) : hex(0x000000, 0.08)).setFill()
    NSBezierPath(roundedRect: highlight, xRadius: 6, yRadius: 6).fill()
    Mark.statusImage(dot: .on, dimmed: false)
        .draw(in: CGRect(x: iconX, y: 6, width: 22, height: 18), from: .zero, operation: .sourceOver,
              fraction: 1, respectFlipped: true, hints: nil)
}

try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
func save(_ data: Data, _ name: String) {
    try! data.write(to: out.appendingPathComponent(name))
    print("  \(name)")
}

// 1. Portada: barra de menús, panel principal y ajustes.
for dark in [false, true] {
    let mode = dark ? "dark" : "light"
    let panel = image("panel-\(mode).png")
    let settings = image("settings-\(mode).png")
    let W: CGFloat = 900, H: CGFloat = 590
    save(canvas(W, H, dark: dark) { ctx in
        let bg = CGRect(x: 0, y: 0, width: W, height: H)
        if dark { gradient(ctx, bg, hex(0x0F1A16), hex(0x0B0F0E)) } else { gradient(ctx, bg, hex(0xEEF6F1), hex(0xDCEFE5)) }
        menuBar(ctx, width: W, dark: dark, iconX: 599)
        drawPanel(settings, at: CGPoint(x: 150, y: 96), width: 300, dark: dark, in: ctx)
        drawPanel(panel, at: CGPoint(x: 440, y: 42), width: 340, dark: dark, in: ctx)
    }, "hero-\(mode).png")
}

// 2. Estados del ícono en la barra de menús.
for dark in [false, true] {
    let mode = dark ? "dark" : "light"
    let states: [(Mark.Dot, Bool, String)] = [(.on, false, "Encendido"), (.busy, false, "Arrancando / apagando"), (.none, true, "Apagado")]
    let W: CGFloat = 640, H: CGFloat = 96
    save(canvas(W, H, dark: dark) { ctx in
        (dark ? hex(0x111A16) : hex(0xFFFFFF)).setFill()
        NSBezierPath(roundedRect: CGRect(x: 0, y: 0, width: W, height: H), xRadius: 14, yRadius: 14).fill()
        let colW = W / 3
        for (i, s) in states.enumerated() {
            let cx = colW * CGFloat(i) + colW / 2
            let chip = CGRect(x: cx - 34, y: 16, width: 68, height: 36)
            (dark ? hex(0x1C1F1E) : hex(0xF4F7F5)).setFill()
            NSBezierPath(roundedRect: chip, xRadius: 9, yRadius: 9).fill()
            Mark.statusImage(dot: s.0, dimmed: s.1)
                .draw(in: CGRect(x: cx - 22, y: 16 + 18 - 18, width: 44, height: 36), from: .zero,
                      operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            let w = textWidth(s.2, size: 12, weight: .medium)
            text(s.2, size: 12, weight: .medium, color: dark ? hex(0x7D938A) : hex(0x5C6B64), at: CGPoint(x: cx - w / 2, y: 62))
        }
    }, "menubar-\(mode).png")
}

// 3. Ventana del instalador: fondo real del dmg con los íconos donde los pone Finder.
guard let dmg = NSImage(contentsOfFile: dmgBackground) else { exit(1) }
let appIcon = NSWorkspace.shared.icon(forFile: appPath)
let appsIcon = NSWorkspace.shared.icon(forFile: "/Applications")
save(canvas(660, 468) { ctx in
    let frame = CGRect(x: 0, y: 0, width: 660, height: 468)
    let path = NSBezierPath(roundedRect: frame, xRadius: 12, yRadius: 12)
    ctx.saveGState(); path.addClip()
    hex(0xE9ECEA).setFill(); frame.fill()
    for (i, c) in [hex(0xFF5F57), hex(0xFEBC2E), hex(0x28C840)].enumerated() {
        c.setFill()
        NSBezierPath(ovalIn: CGRect(x: 14 + CGFloat(i) * 20, y: 8, width: 12, height: 12)).fill()
    }
    let title = "ModelNap"
    text(title, size: 13, weight: .semibold, color: hex(0x3C3C3C), at: CGPoint(x: 330 - textWidth(title, size: 13, weight: .semibold) / 2, y: 5))
    dmg.draw(in: CGRect(x: 0, y: 28, width: 660, height: 440), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    for (icon, center, label) in [(appIcon, CGPoint(x: 170, y: 228), "ModelNap"), (appsIcon, CGPoint(x: 490, y: 228), "Aplicaciones")] {
        icon.draw(in: CGRect(x: center.x - 52, y: center.y - 52, width: 104, height: 104), from: .zero,
                  operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        text(label, size: 12, color: hex(0x1D1D1F), at: CGPoint(x: center.x - textWidth(label, size: 12) / 2, y: center.y + 58))
    }
    ctx.restoreGState()
    hex(0x000000, 0.12).setStroke()
    path.lineWidth = 1
    path.stroke()
}, "installer.png")

// 4. Ícono de la app.
save(canvas(128, 128) { ctx in
    ctx.translateBy(x: 0, y: 128); ctx.scaleBy(x: 1, y: -1)
    Mark.drawAppIcon(in: ctx, px: 128)
}, "icon.png")

// 5. Panel en inglés, para la sección de idiomas.
save(canvas(360, 360 * image("panel-en-light.png").size.height / image("panel-en-light.png").size.width + 20) { ctx in
    drawPanel(image("panel-en-light.png"), at: CGPoint(x: 10, y: 6), width: 340, dark: false, in: ctx)
}, "panel-en.png")
