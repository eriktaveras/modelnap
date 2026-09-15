import AppKit

// Archivos del logo para la web y redes, generados desde Sources/Logo.swift.
//   logo <salida-dir>

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "logo")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

let background = "#101318", green = "#34D399", mint = "#A7F3D0", forest = "#047857", ink = "#0F1614"

func cg(_ hex: String) -> CGColor {
    let v = UInt32(hex.dropFirst(), radix: 16)!
    return CGColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                   blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}

func png(px: Int, _ draw: (CGContext, CGFloat) -> Void) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    draw(NSGraphicsContext(bitmapImageRep: rep)!.cgContext, CGFloat(px))
    return rep.representation(using: .png, properties: [:])!
}

func icon(_ px: Int) -> Data {
    png(px: px) { ctx, s in Logo.drawIcon(in: ctx, px: s, background: cg(background), color: cg(green), zColor: cg(mint)) }
}

func mark(_ px: Int, _ color: String) -> Data {
    png(px: px) { ctx, s in Logo.draw(in: ctx, rect: CGRect(x: 0, y: 0, width: s, height: s), color: cg(color)) }
}

/// .ico con entradas PNG (lo aceptan todos los navegadores actuales).
func ico(_ sizes: [Int]) -> Data {
    let images = sizes.map { ($0, icon($0)) }
    var d = Data()
    func u16(_ v: Int) { withUnsafeBytes(of: UInt16(v).littleEndian) { d.append(contentsOf: $0) } }
    func u32(_ v: Int) { withUnsafeBytes(of: UInt32(v).littleEndian) { d.append(contentsOf: $0) } }
    u16(0); u16(1); u16(images.count)
    var offset = 6 + 16 * images.count
    for (size, data) in images {
        d.append(UInt8(size % 256)); d.append(UInt8(size % 256)); d.append(0); d.append(0)
        u16(1); u16(32); u32(data.count); u32(offset)
        offset += data.count
    }
    images.forEach { d.append($0.1) }
    return d
}

func write(_ data: Data, _ name: String) {
    try! data.write(to: out.appendingPathComponent(name))
    print("  \(name)")
}

write(Data(Logo.svg(color: green, zColor: mint, background: background).utf8), "modelnap-icon.svg")
for px in [1024, 512, 256] { write(icon(px), "modelnap-icon-\(px).png") }
write(icon(180), "apple-touch-icon.png")

write(Data(Logo.svg(color: green).utf8), "modelnap-mark-green.svg")
write(Data(Logo.svg(color: forest).utf8), "modelnap-mark-forest.svg")
write(Data(Logo.svg(color: ink).utf8), "modelnap-mark-ink.svg")
write(Data(Logo.svg(color: "#FFFFFF").utf8), "modelnap-mark-white.svg")
write(mark(512, green), "modelnap-mark-green-512.png")
write(mark(512, forest), "modelnap-mark-forest-512.png")

write(Data(Logo.svg(color: green, zColor: mint, background: background).utf8), "favicon.svg")
write(ico([16, 32, 48]), "favicon.ico")
