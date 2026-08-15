import AppKit
import ServiceManagement

// MARK: - Configuration

let profileIdentifier = "local.cameratoggle.off"
let profileTopUUID = "7A3C9B1D-52E1-4F6A-9C8B-2D4E0F1A3B5C"
let profilePayloadUUID = "9E2D4A6C-8B0F-4C3E-A1D7-5F9E2B4C6D8A"

/// macOS 26: /usr/bin/profiles; older systems: /usr/sbin/profiles.
var profilesBinaryPath: String {
    FileManager.default.isExecutableFile(atPath: "/usr/bin/profiles")
        ? "/usr/bin/profiles" : "/usr/sbin/profiles"
}

var profileFileURL: URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".camera-toggle", isDirectory: true)
        .appendingPathComponent("camera-off.mobileconfig")
}

var logFileURL: URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".camera-toggle", isDirectory: true)
        .appendingPathComponent("debug.log")
}

func log(_ message: String) {
    let line = "\(Date()) \(message)\n"
    let data = line.data(using: .utf8) ?? Data()
    if let handle = try? FileHandle(forWritingTo: logFileURL) {
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
    } else {
        try? data.write(to: logFileURL)
    }
}

let mobileconfig = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>PayloadType</key>
            <string>com.apple.applicationaccess</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>PayloadIdentifier</key>
            <string>\(profileIdentifier).restrictions</string>
            <key>PayloadUUID</key>
            <string>\(profilePayloadUUID)</string>
            <key>PayloadDisplayName</key>
            <string>Camera Off</string>
            <key>PayloadDescription</key>
            <string>Disables the built-in and external cameras system-wide.</string>
            <key>PayloadOrganization</key>
            <string>CameraToggle</string>
            <key>allowCamera</key>
            <false/>
        </dict>
    </array>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
    <key>PayloadIdentifier</key>
    <string>\(profileIdentifier)</string>
    <key>PayloadUUID</key>
    <string>\(profileTopUUID)</string>
    <key>PayloadDisplayName</key>
    <string>CameraToggle — 摄像头已禁用</string>
    <key>PayloadDescription</key>
    <string>由 CameraToggle 安装。删除此描述文件即可恢复摄像头。</string>
    <key>PayloadOrganization</key>
    <string>CameraToggle</string>
    <key>PayloadRemovalDisallowed</key>
    <false/>
</dict>
</plist>
"""

// MARK: - Helpers

enum CameraState {
    case enabled
    case disabled
    case unknown
}

func ensureProfileFile() throws {
    try FileManager.default.createDirectory(
        at: profileFileURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try mobileconfig.write(to: profileFileURL, atomically: true, encoding: .utf8)
}

/// Run a shell command with administrator privileges.
/// Pops the native password dialog; returns (success, combinedOutput).
func runPrivileged(_ command: String, completion: @escaping (Bool, String) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err

        do {
            try process.run()
        } catch {
            DispatchQueue.main.async { completion(false, "无法启动 osascript: \(error.localizedDescription)") }
            return
        }
        process.waitUntilExit()

        let data = out.fileHandleForReading.readDataToEndOfFile()
            + err.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let ok = process.terminationStatus == 0
        DispatchQueue.main.async { completion(ok, output) }
    }
}

/// Non-privileged run of the profiles tool; returns (success, output).
func runProfiles(_ arguments: [String], completion: @escaping (Bool, String) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: profilesBinaryPath)
        process.arguments = arguments
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do {
            try process.run()
        } catch {
            DispatchQueue.main.async { completion(false, error.localizedDescription) }
            return
        }
        process.waitUntilExit()
        let data = out.fileHandleForReading.readDataToEndOfFile()
            + err.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        DispatchQueue.main.async {
            completion(process.terminationStatus == 0, output)
        }
    }
}

/// Non-privileged read of installed profiles; best effort.
func installedProfileOutput() -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: profilesBinaryPath)
    process.arguments = ["list"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()
    do {
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        log("profiles list exit=\(process.terminationStatus) output=\(output.prefix(300))")
        guard process.terminationStatus == 0 else { return nil }
        return output
    } catch {
        log("profiles list failed to launch: \(error.localizedDescription)")
        return nil
    }
}

/// macOS 26 removed the `profiles install` verb — detect once.
func cliInstallSupported() -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: profilesBinaryPath)
    process.arguments = ["install"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    do {
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return !output.contains("no longer supports installs")
    } catch {
        return false
    }
}

func showAlert(_ message: String, informative: String = "") {
    let alert = NSAlert()
    alert.messageText = message
    alert.informativeText = informative
    alert.alertStyle = .warning
    alert.runModal()
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var state: CameraState = .unknown
    var busy = false
    var installPollTimer: Timer?
    let installVerbSupported = cliInstallSupported()

    var launchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("launch lang=\(L10n.language.rawValue) profilesBinary=\(profilesBinaryPath) cliInstall=\(installVerbSupported) autoStart=\(SMAppService.mainApp.status.rawValue)")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        detectState()
        rebuildMenu()
    }

    // MARK: State

    func detectState() {
        if let output = installedProfileOutput(), output.contains(profileIdentifier) {
            state = .disabled
        } else if UserDefaults.standard.object(forKey: "cameraDisabled") != nil {
            state = UserDefaults.standard.bool(forKey: "cameraDisabled") ? .disabled : .enabled
        } else {
            state = .enabled
        }
        log("detectState -> \(state)")
    }

    // MARK: UI

    func rebuildMenu() {
        let menu = NSMenu()

        let stateTitle: String
        let symbolName: String
        switch state {
        case .enabled:
            stateTitle = L10n.tr("camera.enabled")
            symbolName = "video.fill"
        case .disabled:
            stateTitle = L10n.tr("camera.disabled")
            symbolName = "video.slash.fill"
        case .unknown:
            stateTitle = L10n.tr("camera.unknown")
            symbolName = "video.fill"
        }

        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: stateTitle) {
                button.image = image
            } else {
                button.title = state == .disabled ? "🚫" : "📹"
            }
        }

        let stateItem = NSMenuItem(title: stateTitle, action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)
        menu.addItem(.separator())

        let actionTitle = busy
            ? L10n.tr("action.processing")
            : (state == .disabled ? L10n.tr("action.enable") : L10n.tr("action.disable"))
        let actionItem = NSMenuItem(title: actionTitle, action: #selector(toggleCamera), keyEquivalent: "t")
        actionItem.target = self
        actionItem.isEnabled = !busy
        menu.addItem(actionItem)

        let refresh = NSMenuItem(title: L10n.tr("action.refresh"), action: #selector(refreshState), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let launchItem = NSMenuItem(
            title: L10n.tr("action.autostart"),
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: "l"
        )
        launchItem.target = self
        launchItem.state = launchAtLoginEnabled ? .on : .off
        menu.addItem(launchItem)

        // Language submenu
        let langMenu = NSMenu(title: L10n.tr("menu.language"))
        for lang in AppLanguage.allCases {
            let item = NSMenuItem(
                title: lang.displayName,
                action: #selector(selectLanguage(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = lang.rawValue
            item.state = L10n.language == lang ? .on : .off
            langMenu.addItem(item)
        }
        let langItem = NSMenuItem(title: L10n.tr("menu.language"), action: nil, keyEquivalent: "")
        langItem.submenu = langMenu
        menu.addItem(langItem)

        let reveal = NSMenuItem(title: L10n.tr("action.reveal"), action: #selector(revealProfile), keyEquivalent: "")
        reveal.target = self
        menu.addItem(.separator())
        menu.addItem(reveal)

        let quit = NSMenuItem(
            title: L10n.tr("action.quit"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)

        statusItem.menu = menu
    }

    // MARK: Actions

    @objc func toggleCamera() {
        state == .disabled ? enableCamera() : disableCamera()
    }

    @objc func refreshState() {
        detectState()
        rebuildMenu()
    }

    @objc func selectLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let lang = AppLanguage(rawValue: raw),
              lang != L10n.language else { return }
        L10n.setLanguage(lang)
        log("language -> \(lang.rawValue)")
        GuideWindowController.reset()
        rebuildMenu()
    }

    @objc func toggleLaunchAtLogin() {
        do {
            if launchAtLoginEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            showAlert(
                L10n.tr("alert.autostart.title"),
                informative: "\(error.localizedDescription)\n\n\(L10n.tr("alert.autostart.body"))"
            )
        }
        log("toggleLaunchAtLogin -> status=\(SMAppService.mainApp.status.rawValue)")
        rebuildMenu()
    }

    func disableCamera() {
        guard !busy else { return }
        do {
            try ensureProfileFile()
        } catch {
            showAlert(L10n.tr("alert.writeProfile.title"), informative: error.localizedDescription)
            return
        }

        busy = true
        rebuildMenu()

        if installVerbSupported {
            let command = "\(profilesBinaryPath) install -type configuration -path '\(profileFileURL.path)'"
            runPrivileged(command) { ok, output in
                self.busy = false
                self.finishToggle(ok: ok, output: output, disabling: true)
            }
        } else {
            // macOS 26+: stage the profile, bring System Settings Profiles
            // pane to the front, and show a step-by-step guide window.
            GuideWindowController.show()
            NSWorkspace.shared.open(profileFileURL)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.Profiles-Settings.extension")!
                )
            }
            pollForInstall(timeout: 180)
        }
    }

    func pollForInstall(timeout: TimeInterval) {
        let start = Date()
        installPollTimer?.invalidate()
        installPollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            DispatchQueue.global(qos: .utility).async {
                let installed = installedProfileOutput()?.contains(profileIdentifier) ?? false
                DispatchQueue.main.async {
                    if installed {
                        timer.invalidate()
                        self.installPollTimer = nil
                        self.busy = false
                        GuideWindowController.dismiss()
                        self.finishToggle(ok: true, output: "", disabling: true)
                    } else if Date().timeIntervalSince(start) > timeout {
                        timer.invalidate()
                        self.installPollTimer = nil
                        self.busy = false
                        self.state = .unknown
                        self.rebuildMenu()
                        GuideWindowController.updateFooter(L10n.tr("guide.footerTimeout"))
                    }
                }
            }
        }
    }

    func enableCamera() {
        guard !busy else { return }

        // Nothing to remove — profile is already gone.
        if let output = installedProfileOutput(), !output.contains(profileIdentifier) {
            state = .enabled
            UserDefaults.standard.set(false, forKey: "cameraDisabled")
            rebuildMenu()
            return
        }

        busy = true
        rebuildMenu()

        // Only ever removes this app's own profile identifier — never "-all".
        // Manually installed user-scoped profiles can be removed without
        // privileges; fall back to the privileged path (with -user) only if
        // the profile is device-scoped.
        runProfiles(["remove", "-forced", "-identifier", profileIdentifier]) { ok, output in
            if ok {
                self.busy = false
                self.finishToggle(ok: true, output: "", disabling: false)
                return
            }
            let command = "\(profilesBinaryPath) remove -forced -user '\(NSUserName())' -identifier '\(profileIdentifier)'"
            runPrivileged(command) { ok2, output2 in
                self.busy = false
                self.finishToggle(ok: ok2, output: output2, disabling: false)
            }
        }
    }

    private func finishToggle(ok: Bool, output: String, disabling: Bool) {
        log("finishToggle ok=\(ok) disabling=\(disabling) output=\(output.prefix(300))")
        if ok {
            state = disabling ? .disabled : .enabled
            UserDefaults.standard.set(disabling, forKey: "cameraDisabled")
        } else {
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            showAlert(
                L10n.tr("alert.opFailed.title"),
                informative: trimmed.isEmpty
                    ? L10n.tr("alert.opFailed.cancelled")
                    : L10n.tr("alert.opFailed.outputPrefix") + trimmed
            )
        }
        rebuildMenu()
    }

    @objc func revealProfile() {
        do {
            try ensureProfileFile()
            NSWorkspace.shared.activateFileViewerSelecting([profileFileURL])
        } catch {
            showAlert(L10n.tr("alert.revealFailed.title"), informative: error.localizedDescription)
        }
    }
}

// MARK: - Bootstrap

// Test hook: print the auto-detected language and exit.
//   ./CameraToggle --detect-lang
if CommandLine.arguments.contains("--detect-lang") {
    print(L10n.language.rawValue)
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
