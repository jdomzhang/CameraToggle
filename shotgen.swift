// 生成 README 用营销图与 UI 界面图（依据 app-store-screenshots skill 的设计原则）
// swiftc -O -o /tmp/shotgen shotgen.swift && /tmp/shotgen
import AppKit

let outDir = "screenshots"

// MARK: - 基础工具

func render(widthPx: Int, heightPx: Int, draw: (NSRect) -> Void) -> NSBitmapImageRep {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: widthPx, pixelsHigh: heightPx, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { fatalError("bitmap") }
    rep.size = NSSize(width: widthPx, height: heightPx)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(NSRect(x: 0, y: 0, width: widthPx, height: heightPx))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func save(_ rep: NSBitmapImageRep, _ name: String) {
    try! rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
    print("wrote \(outDir)/\(name)")
}

func symbol(_ name: String, pointSize: CGFloat, weight: NSFont.Weight = .regular, color: NSColor) -> NSImage? {
    guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: pointSize, weight: weight)) else { return nil }
    let image = NSImage(size: base.size)
    image.lockFocus()
    base.draw(in: NSRect(origin: .zero, size: base.size))
    color.set()
    NSRect(origin: .zero, size: base.size).fill(using: .sourceAtop)
    image.unlockFocus()
    return image
}

func para(align: NSTextAlignment = .center) -> NSMutableParagraphStyle {
    let p = NSMutableParagraphStyle()
    p.alignment = align
    return p
}

func drawCentered(_ text: String, font: NSFont, color: NSColor, cx: CGFloat, cy: CGFloat) {
    let attributed = NSAttributedString(string: text, attributes: [
        .font: font, .foregroundColor: color, .paragraphStyle: para(),
    ])
    let size = attributed.size()
    attributed.draw(in: NSRect(x: cx - 10_000, y: cy - size.height / 2, width: 20_000, height: size.height + 4))
}

func drawLeft(_ text: String, font: NSFont, color: NSColor, x: CGFloat, cy: CGFloat) {
    let attributed = NSAttributedString(string: text, attributes: [
        .font: font, .foregroundColor: color, .paragraphStyle: para(align: .left),
    ])
    let size = attributed.size()
    attributed.draw(at: NSPoint(x: x, y: cy - size.height / 2))
}

func roundedShadowRect(_ rect: NSRect, radius: CGFloat, fill: NSColor, shadow: NSShadow?) {
    if let shadow { shadow.set() } else { NSShadow().set() }
    fill.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
    NSShadow().set()
}

// MARK: - 菜单栏 + 下拉菜单 UI 卡片（s = 缩放，坐标按 pt 计算）

struct MenuItem {
    enum Kind {
        case title(String)                 // 状态行（灰色）
        case action(String)                // 普通项
        case actionCheck(String)           // 带 ✓
        case submenu(String, [(String, Bool)])  // 子菜单（展开画）
        case separator
    }
    var kind: Kind
}

func menuCard(lang: String) -> (NSBitmapImageRep, NSSize) {
    let s: CGFloat = 2
    let items: [MenuItem]
    if lang == "zh" {
        items = [
            .init(kind: .title("摄像头：已禁用（全局）")),
            .init(kind: .separator),
            .init(kind: .action("启用摄像头…")),
            .init(kind: .action("刷新状态")),
            .init(kind: .actionCheck("登录时自动启动")),
            .init(kind: .submenu("语言", [("中文", true), ("English", false)])),
            .init(kind: .separator),
            .init(kind: .action("在 Finder 中显示描述文件…")),
            .init(kind: .action("退出 CameraToggle")),
        ]
    } else {
        items = [
            .init(kind: .title("Camera: Disabled (system-wide)")),
            .init(kind: .separator),
            .init(kind: .action("Enable Camera…")),
            .init(kind: .action("Refresh Status")),
            .init(kind: .actionCheck("Launch at Login")),
            .init(kind: .submenu("Language", [("中文", true), ("English", false)])),
            .init(kind: .separator),
            .init(kind: .action("Reveal Profile in Finder…")),
            .init(kind: .action("Quit CameraToggle")),
        ]
    }

    let stripW: CGFloat = 640
    let panelW: CGFloat = 300
    let panelPadV: CGFloat = 6
    let itemH: CGFloat = 27
    let sepH: CGFloat = 10
    let titleH: CGFloat = 28

    var panelH = panelPadV * 2
    for item in items {
        switch item.kind {
        case .title: panelH += titleH
        case .action, .actionCheck: panelH += itemH
        case .submenu(_, let subs): panelH += itemH + CGFloat(subs.count) * 22
        case .separator: panelH += sepH
        }
    }

    let margin: CGFloat = 48
    let cardW = stripW + margin * 2
    let cardH = 32 + 10 + panelH + margin * 2

    let rep = render(widthPx: Int(cardW * s), heightPx: Int(cardH * s)) { _ in
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.scaleBy(x: s, y: s)
        let stripY = cardH - margin - 32
        let panelY = stripY - 10 - panelH
        let panelX = (cardW + panelW) / 2 - 44  // 面板右缘靠近图标下方

        // 菜单栏
        let stripShadow = NSShadow()
        stripShadow.shadowBlurRadius = 12
        stripShadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
        stripShadow.shadowOffset = NSSize(width: 0, height: -6)
        roundedShadowRect(
            NSRect(x: margin, y: stripY, width: stripW, height: 32), radius: 9,
            fill: NSColor(calibratedWhite: 0.11, alpha: 0.94), shadow: stripShadow
        )
        NSColor(calibratedWhite: 1, alpha: 0.12).setStroke()
        let stripPath = NSBezierPath(roundedRect: NSRect(x: margin, y: stripY, width: stripW, height: 32), xRadius: 9, yRadius: 9)
        stripPath.lineWidth = 1
        stripPath.stroke()

        // 左侧 Apple 标志
        if let apple = symbol("apple.logo", pointSize: 15, color: .white) {
            apple.draw(in: NSRect(x: margin + 16, y: stripY + 16 - apple.size.height / 2,
                                  width: apple.size.width, height: apple.size.height))
        }
        // 右侧：时间 + 电池 + Wi-Fi + 摄像头图标
        let white70 = NSColor(calibratedWhite: 1, alpha: 0.85)
        drawLeft("Fri 21:08", font: .monospacedDigitSystemFont(ofSize: 12, weight: .regular),
                 color: white70, x: margin + stripW - 190, cy: stripY + 16)
        var iconsX = margin + stripW - 14
        if let cam = symbol("video.slash.fill", pointSize: 15, color: .white) {
            cam.draw(in: NSRect(x: iconsX - cam.size.width, y: stripY + 16 - cam.size.height / 2,
                                width: cam.size.width, height: cam.size.height))
            iconsX -= cam.size.width + 14
        }
        if let wifi = symbol("wifi", pointSize: 13, color: white70) {
            wifi.draw(in: NSRect(x: iconsX - wifi.size.width, y: stripY + 16 - wifi.size.height / 2,
                                 width: wifi.size.width, height: wifi.size.height))
            iconsX -= wifi.size.width + 12
        }
        if let battery = symbol("battery.100", pointSize: 16, color: white70) {
            battery.draw(in: NSRect(x: iconsX - battery.size.width, y: stripY + 16 - battery.size.height / 2,
                                    width: battery.size.width, height: battery.size.height))
        }

        // 下拉面板
        let panelShadow = NSShadow()
        panelShadow.shadowBlurRadius = 18
        panelShadow.shadowColor = NSColor.black.withAlphaComponent(0.5)
        panelShadow.shadowOffset = NSSize(width: 0, height: -8)
        let panelRect = NSRect(x: panelX, y: panelY, width: panelW, height: panelH)
        roundedShadowRect(panelRect, radius: 8,
                          fill: NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.10, alpha: 0.97),
                          shadow: panelShadow)
        NSColor(calibratedWhite: 1, alpha: 0.10).setStroke()
        let panelPath = NSBezierPath(roundedRect: panelRect, xRadius: 8, yRadius: 8)
        panelPath.lineWidth = 1
        panelPath.stroke()

        let itemFont = NSFont.systemFont(ofSize: 13)
        let labelColor = NSColor(calibratedWhite: 0.96, alpha: 1)
        let dimColor = NSColor(calibratedWhite: 0.62, alpha: 1)

        var y = panelY + panelH - panelPadV
        for item in items {
            switch item.kind {
            case .title(let text):
                drawLeft(text, font: .systemFont(ofSize: 13, weight: .semibold), color: dimColor,
                         x: panelX + 14, cy: y - titleH / 2)
                y -= titleH
            case .separator:
                y -= sepH / 2
                NSColor(calibratedWhite: 1, alpha: 0.14).setFill()
                NSRect(x: panelX + 12, y: panelY == 0 ? 0 : y, width: panelW - 24, height: 1).fill()
                y -= sepH / 2
            case .action(let text):
                drawLeft(text, font: itemFont, color: labelColor, x: panelX + 14, cy: y - itemH / 2)
                y -= itemH
            case .actionCheck(let text):
                if let check = symbol("checkmark", pointSize: 11, weight: .bold, color: labelColor) {
                    check.draw(in: NSRect(x: panelX + 12, y: y - itemH / 2 - check.size.height / 2,
                                          width: check.size.width, height: check.size.height))
                }
                drawLeft(text, font: itemFont, color: labelColor, x: panelX + 32, cy: y - itemH / 2)
                y -= itemH
            case .submenu(let text, let subs):
                drawLeft(text, font: itemFont, color: labelColor, x: panelX + 14, cy: y - itemH / 2)
                if let chev = symbol("chevron.right", pointSize: 9, weight: .semibold,
                                     color: NSColor(calibratedWhite: 0.55, alpha: 1)) {
                    chev.draw(in: NSRect(x: panelX + panelW - 18, y: y - itemH / 2 - chev.size.height / 2,
                                         width: chev.size.width, height: chev.size.height))
                }
                y -= itemH
                for (subText, checked) in subs {
                    if checked, let check = symbol("checkmark", pointSize: 10, weight: .bold, color: labelColor) {
                        check.draw(in: NSRect(x: panelX + 34, y: y - 11 - check.size.height / 2,
                                              width: check.size.width, height: check.size.height))
                    }
                    drawLeft(subText, font: itemFont, color: labelColor, x: panelX + 54, cy: y - 11)
                    y -= 22
                }
            }
        }
    }
    return (rep, NSSize(width: cardW, height: cardH))
}

// MARK: - 引导窗口 UI 卡片

func guideCard(lang: String) -> (NSBitmapImageRep, NSSize) {
    let s: CGFloat = 2
    let w: CGFloat = 520
    let h: CGFloat = 470

    struct Step { let sym: String; let title: String; let sub: [String] }
    let intro: [String]
    let steps: [Step]
    let footer: [String]
    let hint: [String]
    if lang == "zh" {
        intro = ["macOS 26 出于安全要求，安装描述文件需要在「系统设置」中手动确认。",
                 "跟着下面 3 步操作（约 15 秒）："]
        steps = [
            Step(sym: "gearshape.fill", title: "打开 系统设置 → 描述文件",
                 sub: ["系统设置已自动打开并定位；稍等 1–2 秒即可看到。"]),
            Step(sym: "square.and.arrow.down", title: "点击「安装…」",
                 sub: ["选中 CameraToggle 描述文件，点「安装…」按钮。"]),
            Step(sym: "touchid", title: "确认安装",
                 sub: ["用 Touch ID 或输入密码确认，完成后图标变为禁用状态。"]),
        ]
        footer = ["等待安装完成… 本窗口自动关闭，所有 App 的摄像头即被禁用。"]
        hint = ["以后恢复摄像头：点菜单栏「启用摄像头…」，无需密码。"]
    } else {
        intro = ["For security, macOS confirms profiles in System Settings.",
                 "Follow these 3 steps (about 15 seconds):"]
        steps = [
            Step(sym: "gearshape.fill", title: "Open System Settings → Profiles",
                 sub: ["Settings opens here automatically — give it 1–2 seconds."]),
            Step(sym: "square.and.arrow.down", title: "Click \"Install…\"",
                 sub: ["Select the CameraToggle profile, click Install."]),
            Step(sym: "touchid", title: "Confirm with Touch ID",
                 sub: ["Or type your password. The menu bar icon flips to off."]),
        ]
        footer = ["Waiting for install… this window closes itself when done —"]
        hint = ["Re-enable anytime from the menu bar. No password needed."]
    }

    let rep = render(widthPx: Int(w * s), heightPx: Int(h * s)) { _ in
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.scaleBy(x: s, y: s)

        let shadow = NSShadow()
        shadow.shadowBlurRadius = 22
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
        shadow.shadowOffset = NSSize(width: 0, height: -10)
        let frame = NSRect(x: 0, y: 0, width: w, height: h)
        roundedShadowRect(frame, radius: 10, fill: NSColor(calibratedWhite: 0.94, alpha: 1), shadow: shadow)

        // 标题栏
        _ = NSRect(x: 0, y: h - 36, width: w, height: 36)
        NSColor(calibratedWhite: 0.88, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 0, y: h - 36, width: w, height: 36), xRadius: 10, yRadius: 10).fill()
        NSRect(x: 0, y: h - 36, width: w, height: 20).fill()
        NSColor(calibratedWhite: 0.75, alpha: 1).setFill()
        NSRect(x: 0, y: h - 36, width: w, height: 1).fill()

        let dotColors: [NSColor] = [
            NSColor(srgbRed: 1.00, green: 0.37, blue: 0.34, alpha: 1),
            NSColor(srgbRed: 0.99, green: 0.74, blue: 0.18, alpha: 1),
            NSColor(srgbRed: 0.16, green: 0.78, blue: 0.25, alpha: 1),
        ]
        for (i, c) in dotColors.enumerated() {
            c.setFill()
            NSBezierPath(ovalIn: NSRect(x: 16 + CGFloat(i) * 20, y: h - 24, width: 12, height: 12)).fill()
        }
        drawCentered(lang == "zh" ? "禁用摄像头 · 安装引导" : "Disable Camera · Setup Guide",
                     font: .systemFont(ofSize: 13, weight: .semibold),
                     color: NSColor(calibratedWhite: 0.25, alpha: 1), cx: w / 2, cy: h - 18)

        let ink = NSColor(calibratedWhite: 0.13, alpha: 1)
        let ink2 = NSColor(calibratedWhite: 0.45, alpha: 1)
        var y = h - 36 - 26
        for line in intro {
            drawCentered(line, font: .systemFont(ofSize: 13, weight: .semibold), color: ink, cx: w / 2, cy: y)
            y -= 19
        }
        y -= 10

        let blue = NSColor(srgbRed: 0.04, green: 0.48, blue: 1.0, alpha: 1)
        for step in steps {
            if let icon = symbol(step.sym, pointSize: 30, weight: .medium, color: blue) {
                icon.draw(in: NSRect(x: 24, y: y - 22, width: icon.size.width, height: icon.size.height))
            }
            drawLeft(step.title, font: .systemFont(ofSize: 13, weight: .semibold), color: ink, x: 70, cy: y - 10)
            y -= 27
            for line in step.sub {
                drawLeft(line, font: .systemFont(ofSize: 11), color: ink2, x: 70, cy: y - 6)
                y -= 16
            }
            y -= 16
        }

        for line in footer {
            drawCentered(line, font: .systemFont(ofSize: 11), color: ink2, cx: w / 2, cy: y)
            y -= 16
        }
        y -= 4
        for line in hint {
            drawCentered(line, font: .systemFont(ofSize: 11), color: ink2, cx: w / 2, cy: y)
            y -= 16
        }
    }
    return (rep, NSSize(width: w, height: h))
}

// MARK: - 背景与装饰（设计感底色，非纯白）

func drawBackdrop(_ rect: NSRect) {
    let gradient = NSGradient(
        starting: NSColor(srgbRed: 0.25, green: 0.27, blue: 0.62, alpha: 1),
        ending: NSColor(srgbRed: 0.47, green: 0.22, blue: 0.58, alpha: 1)
    )!
    gradient.draw(in: rect, angle: -60)

    // 柔光
    for (cx, cy, r) in [(rect.width * 0.18, rect.height * 0.85, rect.width * 0.45),
                        (rect.width * 0.88, rect.height * 0.20, rect.width * 0.38)] {
        let glow = NSGradient(starting: NSColor.white.withAlphaComponent(0.10),
                              ending: NSColor.white.withAlphaComponent(0.0))!
        glow.draw(fromCenter: NSPoint(x: cx, y: cy), radius: 0,
                  toCenter: NSPoint(x: cx, y: cy), radius: r, options: [])
    }
    // 星光点缀
    for (x, y, size) in [(0.13, 0.88, 34.0), (0.86, 0.80, 26.0), (0.94, 0.35, 40.0), (0.08, 0.28, 24.0)] {
        if let sparkle = symbol("sparkle", pointSize: size,
                                color: NSColor.white.withAlphaComponent(0.5)) {
            sparkle.draw(in: NSRect(x: rect.width * x - sparkle.size.width / 2,
                                    y: rect.height * y - sparkle.size.height / 2,
                                    width: sparkle.size.width, height: sparkle.size.height))
        }
    }
}

func drawBadge(_ text: String, cx: CGFloat, cy: CGFloat) {
    let attributed = NSAttributedString(string: text, attributes: [
        .font: NSFont.systemFont(ofSize: 20, weight: .medium),
        .foregroundColor: NSColor.white,
        .paragraphStyle: para(),
    ])
    let size = attributed.size()
    let pill = NSRect(x: cx - size.width / 2 - 22, y: cy - size.height / 2 - 10,
                      width: size.width + 44, height: size.height + 20)
    NSColor.black.withAlphaComponent(0.25).setFill()
    NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2).fill()
    attributed.draw(in: NSRect(x: pill.minX, y: pill.minY + (pill.height - size.height) / 2 - 1,
                               width: pill.width, height: size.height + 4))
}

func composite(_ imagePath: String, in rect: NSRect, shadow: Bool = true) {
    guard let image = NSImage(contentsOfFile: imagePath) else { fatalError("missing \(imagePath)") }
    if shadow {
        let s = NSShadow()
        s.shadowBlurRadius = 40
        s.shadowColor = NSColor.black.withAlphaComponent(0.4)
        s.shadowOffset = NSSize(width: 0, height: -14)
        s.set()
    }
    image.draw(in: rect)
    NSShadow().set()
}

/// 等比缩放合成：在 rect 内取最大等比尺寸并居中，避免拉伸变形。
func compositeFit(_ imagePath: String, in rect: NSRect, shadow: Bool = true) {
    guard let image = NSImage(contentsOfFile: imagePath) else { fatalError("missing \(imagePath)") }
    let scale = min(rect.width / image.size.width, rect.height / image.size.height)
    let w = image.size.width * scale
    let h = image.size.height * scale
    composite(imagePath, in: NSRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h), shadow: shadow)
}

// MARK: - Hero 幻灯片（广告式大标题 + UI 卡片）

func heroSlide(lang: String, cardPath: String, out: String) {
    let W = 1600.0, H = 1000.0
    let rep = render(widthPx: Int(W), heightPx: Int(H)) { rect in
        drawBackdrop(rect)

        if lang == "zh" {
            drawCentered("免费开源 · macOS 13+", font: .systemFont(ofSize: 20, weight: .medium),
                         color: .white, cx: W / 2, cy: H - 90)
            drawCentered("你的摄像头，", font: .systemFont(ofSize: 82, weight: .bold), color: .white,
                         cx: W / 2, cy: H - 210)
            drawCentered("你说了算。", font: .systemFont(ofSize: 82, weight: .bold),
                         color: NSColor(srgbRed: 0.82, green: 0.75, blue: 1.0, alpha: 1),
                         cx: W / 2, cy: H - 310)
        } else {
            drawCentered("Free & Open Source · macOS 13+", font: .systemFont(ofSize: 20, weight: .medium),
                         color: .white, cx: W / 2, cy: H - 90)
            drawCentered("Your camera.", font: .systemFont(ofSize: 82, weight: .bold), color: .white,
                         cx: W / 2, cy: H - 210)
            let italic = NSFontManager.shared.convert(
                NSFont.systemFont(ofSize: 82, weight: .bold), toHaveTrait: NSFontTraitMask.italicFontMask
            )
            drawCentered("Your call.", font: italic,
                         color: NSColor(srgbRed: 0.82, green: 0.75, blue: 1.0, alpha: 1),
                         cx: W / 2, cy: H - 310)
        }

        // UI 卡片：等比缩放（卡片原生约 1.78:1 横宽），禁止拉伸
        compositeFit(cardPath, in: NSRect(x: (W - 700) / 2, y: 55, width: 700, height: 430))
    }
    save(rep, out)
}

// MARK: - 引导窗口幻灯片（深蓝底、换节奏）

func guideSlide(lang: String, guidePath: String, menuPath: String, out: String) {
    let W = 1600.0, H = 1000.0
    let rep = render(widthPx: Int(W), heightPx: Int(H)) { rect in
        let gradient = NSGradient(
            starting: NSColor(srgbRed: 0.03, green: 0.05, blue: 0.14, alpha: 1),
            ending: NSColor(srgbRed: 0.10, green: 0.08, blue: 0.28, alpha: 1)
        )!
        gradient.draw(in: rect, angle: -60)
        for (x, y, size) in [(0.10, 0.86, 30.0), (0.90, 0.30, 38.0), (0.05, 0.20, 22.0)] {
            if let sparkle = symbol("sparkle", pointSize: size,
                                    color: NSColor.white.withAlphaComponent(0.35)) {
                sparkle.draw(in: NSRect(x: rect.width * x, y: rect.height * y,
                                        width: sparkle.size.width, height: sparkle.size.height))
            }
        }

        if lang == "zh" {
            drawCentered("引导式设置，", font: .systemFont(ofSize: 76, weight: .bold), color: .white,
                         cx: W / 2, cy: H - 150)
            drawCentered("15 秒搞定。", font: .systemFont(ofSize: 76, weight: .bold),
                         color: NSColor(srgbRed: 1.0, green: 0.77, blue: 0.24, alpha: 1),
                         cx: W / 2, cy: H - 245)
            drawCentered("macOS 26 的安全确认，跟着提示走完即可", font: .systemFont(ofSize: 26),
                         color: NSColor.white.withAlphaComponent(0.75), cx: W / 2, cy: H - 310)
        } else {
            drawCentered("Guided setup,", font: .systemFont(ofSize: 76, weight: .bold), color: .white,
                         cx: W / 2, cy: H - 150)
            let italic = NSFontManager.shared.convert(
                NSFont.systemFont(ofSize: 76, weight: .bold), toHaveTrait: NSFontTraitMask.italicFontMask
            )
            drawCentered("15 seconds.", font: italic,
                         color: NSColor(srgbRed: 1.0, green: 0.77, blue: 0.24, alpha: 1),
                         cx: W / 2, cy: H - 245)
            drawCentered("macOS 26 asks for one manual confirm — we walk you through it",
                         font: .systemFont(ofSize: 26),
                         color: NSColor.white.withAlphaComponent(0.75), cx: W / 2, cy: H - 310)
        }

        // 菜单卡片在背后偏右（等比），引导窗口在前偏左，形成层次
        compositeFit(menuPath, in: NSRect(x: W * 0.50, y: 90, width: 520, height: 460))
        compositeFit(guidePath, in: NSRect(x: W * 0.30 - 30, y: 40, width: 560, height: 506))
    }
    save(rep, out)
}

// MARK: - 顶部 Banner

func drawAppIcon(into rect: NSRect) {
    guard let ctx = NSGraphicsContext.current else { return }
    ctx.saveGraphicsState()
    defer { ctx.restoreGraphicsState() }

    let body = rect.insetBy(dx: rect.width * 0.098, dy: rect.height * 0.098)
    let path = NSBezierPath(roundedRect: body, xRadius: body.width * 0.2245, yRadius: body.height * 0.2245)

    // 先用带阴影的实心圆角矩形打底（渐变填充本身不投影）
    let shadow = NSShadow()
    shadow.shadowBlurRadius = 30
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    NSColor(srgbRed: 0.36, green: 0.25, blue: 0.60, alpha: 1).setFill()
    path.fill()
    NSShadow().set()

    path.addClip()
    NSGradient(
        starting: NSColor(srgbRed: 0.25, green: 0.27, blue: 0.62, alpha: 1),
        ending: NSColor(srgbRed: 0.47, green: 0.22, blue: 0.58, alpha: 1)
    )!.draw(in: body, angle: -70)
    if let glyph = symbol("video.slash.fill", pointSize: rect.width * 0.40, weight: .medium, color: .white) {
        let target = body.insetBy(dx: body.width * 0.24, dy: body.height * 0.24)
        let scale = min(target.width / max(glyph.size.width, 1), target.height / max(glyph.size.height, 1))
        let w = glyph.size.width * scale, h = glyph.size.height * scale
        glyph.draw(in: NSRect(x: body.midX - w / 2, y: body.midY - h / 2, width: w, height: h))
    }
}

func banner(lang: String, menuPath: String, out: String) {
    let W = 2048.0, H = 640.0
    let rep = render(widthPx: Int(W), heightPx: Int(H)) { rect in
        drawBackdrop(rect)

        drawAppIcon(into: NSRect(x: 170, y: (H - 360) / 2, width: 360, height: 360))

        let tx = 620.0
        if lang == "zh" {
            drawLeft("CameraToggle", font: .systemFont(ofSize: 96, weight: .bold), color: .white, x: tx, cy: H / 2 + 60)
            drawLeft("一键全局禁用 / 启用 Mac 摄像头", font: .systemFont(ofSize: 40),
                     color: NSColor.white.withAlphaComponent(0.85), x: tx + 4, cy: H / 2 - 45)
            drawLeft("免费开源 · macOS 13+ · 中文 / English", font: .systemFont(ofSize: 26),
                     color: NSColor.white.withAlphaComponent(0.6), x: tx + 4, cy: H / 2 - 130)
        } else {
            drawLeft("CameraToggle", font: .systemFont(ofSize: 96, weight: .bold), color: .white, x: tx, cy: H / 2 + 60)
            drawLeft("One-click, system-wide camera control for your Mac",
                     font: .systemFont(ofSize: 38),
                     color: NSColor.white.withAlphaComponent(0.85), x: tx + 4, cy: H / 2 - 45)
            drawLeft("Free & open source · macOS 13+ · 中文 / English",
                     font: .systemFont(ofSize: 26),
                     color: NSColor.white.withAlphaComponent(0.6), x: tx + 4, cy: H / 2 - 130)
        }

        // 右下角小菜单条呼应（等比）
        compositeFit(menuPath, in: NSRect(x: W - 640, y: 90, width: 560, height: 460))
    }
    save(rep, out)
}

// MARK: - 导出

let menuEn = menuCard(lang: "en")
save(menuEn.0, "ui-menu-en.png")
let menuZh = menuCard(lang: "zh")
save(menuZh.0, "ui-menu-zh.png")

let guideEn = guideCard(lang: "en")
save(guideEn.0, "ui-guide-en.png")
let guideZh = guideCard(lang: "zh")
save(guideZh.0, "ui-guide-zh.png")

// 图标 512（无多余透明边，用于 README）
let iconRep = render(widthPx: 512, heightPx: 512) { rect in
    drawAppIcon(into: rect)
}
save(iconRep, "icon.png")

heroSlide(lang: "en", cardPath: "\(outDir)/ui-menu-en.png", out: "hero-en.png")
heroSlide(lang: "zh", cardPath: "\(outDir)/ui-menu-zh.png", out: "hero-zh.png")
guideSlide(lang: "en", guidePath: "\(outDir)/ui-guide-en.png", menuPath: "\(outDir)/ui-menu-en.png", out: "guide-en.png")
guideSlide(lang: "zh", guidePath: "\(outDir)/ui-guide-zh.png", menuPath: "\(outDir)/ui-menu-zh.png", out: "guide-zh.png")
banner(lang: "en", menuPath: "\(outDir)/ui-menu-en.png", out: "banner-en.png")
banner(lang: "zh", menuPath: "\(outDir)/ui-menu-zh.png", out: "banner-zh.png")
