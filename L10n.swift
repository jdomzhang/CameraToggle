import Foundation

enum AppLanguage: String, CaseIterable {
    case zh
    case en

    var displayName: String {
        switch self {
        case .zh: return "中文"
        case .en: return "English"
        }
    }
}

enum L10n {
    /// 当前语言。首次启动跟随系统语言（中文系统 → 中文，其他 → 英文），
    /// 用户手动选择后记录在 UserDefaults。
    static var language: AppLanguage = loadInitial()

    private static func loadInitial() -> AppLanguage {
        if let saved = UserDefaults.standard.string(forKey: "appLanguage"),
           let lang = AppLanguage(rawValue: saved) {
            return lang
        }
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("zh") ? .zh : .en
    }

    static func setLanguage(_ lang: AppLanguage) {
        language = lang
        UserDefaults.standard.set(lang.rawValue, forKey: "appLanguage")
    }

    private static let table: [String: [AppLanguage: String]] = [
        // 菜单栏
        "camera.enabled": [.zh: "摄像头：已启用", .en: "Camera: Enabled"],
        "camera.disabled": [.zh: "摄像头：已禁用（全局）", .en: "Camera: Disabled (system-wide)"],
        "camera.unknown": [.zh: "摄像头：状态未知", .en: "Camera: Unknown"],
        "action.processing": [.zh: "处理中…", .en: "Working…"],
        "action.enable": [.zh: "启用摄像头…", .en: "Enable Camera…"],
        "action.disable": [.zh: "禁用摄像头…", .en: "Disable Camera…"],
        "action.refresh": [.zh: "刷新状态", .en: "Refresh Status"],
        "action.autostart": [.zh: "登录时自动启动", .en: "Launch at Login"],
        "action.reveal": [.zh: "在 Finder 中显示描述文件…", .en: "Reveal Profile in Finder…"],
        "action.quit": [.zh: "退出 CameraToggle", .en: "Quit CameraToggle"],
        "menu.language": [.zh: "语言", .en: "Language"],

        // 弹窗
        "alert.opFailed.title": [.zh: "操作未完成", .en: "Action Not Completed"],
        "alert.opFailed.cancelled": [
            .zh: "命令执行失败（可能取消了密码输入）。",
            .en: "The command failed (the password prompt may have been cancelled)."
        ],
        "alert.opFailed.outputPrefix": [.zh: "命令执行失败：\n", .en: "The command failed:\n"],
        "alert.writeProfile.title": [.zh: "无法写入描述文件", .en: "Cannot Write Profile"],
        "alert.revealFailed.title": [.zh: "无法显示描述文件", .en: "Cannot Reveal Profile"],
        "alert.autostart.title": [.zh: "设置开机自启失败", .en: "Failed to Set Launch at Login"],
        "alert.autostart.body": [
            .zh: "把 CameraToggle.app 移动到 /Applications 或 ~/Applications 后重试，通常可以解决。",
            .en: "Moving CameraToggle.app to /Applications or ~/Applications usually fixes this. Then try again."
        ],

        // 引导窗口
        "guide.title": [.zh: "禁用摄像头 · 安装引导", .en: "Disable Camera · Setup Guide"],
        "guide.intro": [
            .zh: "macOS 26 出于安全要求，安装描述文件需要在「系统设置」中手动确认。跟着下面 3 步操作（约 15 秒）：",
            .en: "For security, macOS requires configuration profiles to be confirmed in System Settings. Follow these 3 steps (about 15 seconds):"
        ],
        "guide.step1.title": [.zh: "打开 系统设置 → 描述文件", .en: "Open System Settings → Profiles"],
        "guide.step1.body": [
            .zh: "系统设置已自动打开并定位到「描述文件」页；如果没有看到，稍等 1–2 秒再从左侧列表找。",
            .en: "System Settings has opened at the Profiles page. If you don't see it, wait 1–2 seconds and look in the left sidebar."
        ],
        "guide.step2.title": [.zh: "点击「安装…」", .en: "Click \"Install…\""],
        "guide.step2.body": [
            .zh: "选中「CameraToggle — 摄像头已禁用」这一条，点右侧的「安装…」按钮。",
            .en: "Select the \"CameraToggle — 摄像头已禁用\" entry, then click the \"Install…\" button."
        ],
        "guide.step3.title": [.zh: "确认安装", .en: "Confirm Installation"],
        "guide.step3.body": [
            .zh: "按提示选择「安装」，用 Touch ID 或输入密码确认。",
            .en: "Follow the prompts and confirm with Touch ID or your password."
        ],
        "guide.footer": [
            .zh: "⏳ 等待安装完成… 成功后本窗口自动关闭，菜单栏图标变为 🚫，所有 App 的摄像头即被禁用。",
            .en: "⏳ Waiting for installation… This window closes automatically when done. The menu bar icon turns 🚫 and the camera is disabled for all apps."
        ],
        "guide.footerTimeout": [
            .zh: "⏱ 未检测到安装完成。请在系统设置中完成安装后，点击菜单栏图标的「刷新状态」。",
            .en: "⏱ Installation not detected. Finish it in System Settings, then click \"Refresh Status\" in the menu bar."
        ],
        "guide.hint": [
            .zh: "以后恢复摄像头：点菜单栏图标 → 「启用摄像头…」，无需密码。",
            .en: "To re-enable the camera later: click the menu bar icon → \"Enable Camera…\". No password needed."
        ],
    ]

    static func tr(_ key: String) -> String {
        table[key]?[language] ?? key
    }
}
