import AppKit

// Genera el .iconset con el mismo dibujo que usa la app, sin PNG sueltos.

let sizes: [(px: Int, name: String)] = [
    (16, "icon_16x16"), (32, "icon_16x16@2x"),
    (32, "icon_32x32"), (64, "icon_32x32@2x"),
    (128, "icon_128x128"), (256, "icon_128x128@2x"),
    (256, "icon_256x256"), (512, "icon_256x256@2x"),
    (512, "icon_512x512"), (1024, "icon_512x512@2x"),
]

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write(Data("uso: makeicon <dir.iconset>\n".utf8))
    exit(1)
}

let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

for (px, name) in sizes {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                     pixelsWide: px, pixelsHigh: px,
                                     bitsPerSample: 8, samplesPerPixel: 4,
                                     hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0),
          let gctx = NSGraphicsContext(bitmapImageRep: rep) else {
        FileHandle.standardError.write(Data("no se pudo crear el bitmap \(px)\n".utf8))
        exit(1)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = gctx
    Mark.drawAppIcon(in: gctx.cgContext, px: CGFloat(px))
    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
    try png.write(to: outDir.appendingPathComponent("\(name).png"))
}

print("iconset: \(sizes.count) PNG en \(outDir.path)")
