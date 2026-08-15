import AppKit

/// 「禁用摄像头」在 macOS 26+ 上的图文引导窗口。
final class GuideWindowController: NSWindowController {
    private static var sharedController: GuideWindowController?
    private var footerField: NSTextField!

    static func show() {
        if sharedController == nil {
            sharedController = GuideWindowController()
        }
        sharedController?.window?.center()
        sharedController?.showWindow(nil)
        sharedController?.window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    static func updateFooter(_ text: String) {
        sharedController?.footerField?.stringValue = text
    }

    static func dismiss() {
        sharedController?.close()
    }

    /// 语言切换后调用：关闭并丢弃缓存的窗口，下次以新语言重建。
    static func reset() {
        sharedController?.close()
        sharedController = nil
    }

    init() {
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 480))
        let window = NSWindow(
            contentRect: content.bounds,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.tr("guide.title")
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        window.contentView = content

        let intro = NSTextField(wrappingLabelWithString: L10n.tr("guide.intro"))
        intro.font = .systemFont(ofSize: 13, weight: .semibold)

        let steps: [(String, String, String)] = [
            ("gearshape.fill", L10n.tr("guide.step1.title"), L10n.tr("guide.step1.body")),
            ("square.and.arrow.down", L10n.tr("guide.step2.title"), L10n.tr("guide.step2.body")),
            ("touchid", L10n.tr("guide.step3.title"), L10n.tr("guide.step3.body")),
        ]
        let rows = steps.map(makeRow(symbol:title:subtitle:))

        let footer = NSTextField(wrappingLabelWithString: L10n.tr("guide.footer"))
        footer.font = .systemFont(ofSize: 11)
        footer.textColor = .secondaryLabelColor
        footerField = footer

        let hint = NSTextField(wrappingLabelWithString: L10n.tr("guide.hint"))
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [intro] + rows + [footer, hint])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeRow(symbol: String, title: String, subtitle: String) -> NSView {
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 30, weight: .medium)
        icon.contentTintColor = .controlAccentColor
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let titleLabel = NSTextField(wrappingLabelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        let subtitleLabel = NSTextField(wrappingLabelWithString: subtitle)
        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor

        let text = NSStackView(views: [titleLabel, subtitleLabel])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 2
        text.widthAnchor.constraint(equalToConstant: 400).isActive = true

        let row = NSStackView(views: [icon, text])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }
}

extension GuideWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // 保留实例（isReleasedWhenClosed = false），下次直接复用。
    }
}
