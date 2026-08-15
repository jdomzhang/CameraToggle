// 生成 DMG 安装窗口背景图（660x400，与窗口尺寸一致）
// swiftc -O -o /tmp/dmg-bggen dmg-bggen.swift && /tmp/dmg-bggen <输出路径>
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".github/dmg-template/.background/bg.png"

func para(_ align: NSTextAlignment = .center) -> NSMutableParagraphStyle {
    let p = NSMutableParagraphStyle()
    p.alignment = align
    return p
}

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: 660, pixelsHigh: 400, bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else { fatalError("bitmap") }
rep.size = NSSize(width: 660, height: 400)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let rect = NSRect(x: 0, y: 0, width: 660, height: 400)
NSGradient(
    starting: NSColor(srgbRed: 0.25, green: 0.27, blue: 0.62, alpha: 1),
    ending: NSColor(srgbRed: 0.47, green: 0.22, blue: 0.58, alpha: 1)
)!.draw(in: rect, angle: -60)

func drawCentered(_ text: String, font: NSFont, color: NSColor, cy: CGFloat) {
    let a = NSAttributedString(string: text, attributes: [
        .font: font, .foregroundColor: color, .paragraphStyle: para(),
    ])
    let size = a.size()
    a.draw(in: NSRect(x: 0, y: cy - size.height / 2, width: 660, height: size.height + 4))
}

drawCentered("CameraToggle", font: .systemFont(ofSize: 34, weight: .bold),
             color: .white, cy: 360)
drawCentered("拖入右侧 Applications 文件夹完成安装",
             font: .systemFont(ofSize: 14), color: NSColor.white.withAlphaComponent(0.9), cy: 322)
drawCentered("Drag to the Applications folder to install",
             font: .systemFont(ofSize: 13), color: NSColor.white.withAlphaComponent(0.75), cy: 298)

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
