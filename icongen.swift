// 生成 CameraToggle 的 App 图标：AppIcon.iconset/ → AppIcon.icns（配合 iconutil）
import AppKit

func tintedSymbol(_ name: String, pointSize: CGFloat, color: NSColor) -> NSImage? {
    guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: pointSize, weight: .medium)) else { return nil }
    let image = NSImage(size: base.size)
    image.lockFocus()
    base.draw(in: NSRect(origin: .zero, size: base.size))
    color.set()
    NSRect(origin: .zero, size: base.size).fill(using: .sourceAtop)
    image.unlockFocus()
    return image
}

func drawIcon(size: CGFloat) {
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()

    // macOS Big Sur 风格圆角方形（squircle 近似）+ 渐变底
    let inset = size * 0.0977
    let body = rect.insetBy(dx: inset, dy: inset)
    let path = NSBezierPath(roundedRect: body, xRadius: body.width * 0.2245, yRadius: body.height * 0.2245)
    path.addClip()
    NSGradient(
        starting: NSColor(srgbRed: 0.25, green: 0.27, blue: 0.62, alpha: 1),
        ending: NSColor(srgbRed: 0.47, green: 0.22, blue: 0.58, alpha: 1)
    )!.draw(in: body, angle: -70)

    // 白色摄像头（带斜杠）图案
    if let glyph = tintedSymbol("video.slash.fill", pointSize: size * 0.42, color: .white) {
        let target = body.insetBy(dx: body.width * 0.24, dy: body.height * 0.24)
        let gs = glyph.size
        let scale = min(target.width / max(gs.width, 1), target.height / max(gs.height, 1))
        let w = gs.width * scale, h = gs.height * scale
        glyph.draw(in: NSRect(x: body.midX - w / 2, y: body.midY - h / 2, width: w, height: h))
    }
}

func renderPNG(px: Int, to path: String) throws {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { fatalError("cannot create bitmap") }
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    drawIcon(size: CGFloat(px))
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]

let dir = "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
for (px, name) in sizes {
    try renderPNG(px: px, to: "\(dir)/\(name)")
    print("wrote \(dir)/\(name)")
}
