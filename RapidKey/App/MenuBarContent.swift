import AppKit
import SwiftUI

struct MenuBarContent: View {
    let appDelegate: AppDelegate
    @ObservedObject var configStore: ConfigStore
    @ObservedObject var updateChecker: UpdateChecker

    var body: some View {
        Button("Show [\(configStore.config.leader.displayString)]") {
            appDelegate.showPanel()
        }

        if case .doubleTapModifier = configStore.config.leader,
           !InputMonitoringPermission.isGranted {
            Button("Grant Input Monitoring…") {
                InputMonitoringPermission.request()
                appDelegate.reapplyLeader()
            }
        }

        Button("Open Config Folder") {
            NSWorkspace.shared.open(ConfigPaths.configDirectoryURL)
        }

        Divider()

        updateStatusSection

        Button("Check for Updates…") {
            updateChecker.check(manual: true)
        }
        .disabled(updateChecker.status == .checking)

        Divider()

        Button("About RapidKey") {
            Self.showAbout()
        }

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }

    @ViewBuilder
    private var updateStatusSection: some View {
        switch updateChecker.status {
        case .updateAvailable(let version, _):
            Button("Update Available: v\(version)") {
                updateChecker.presentUpdateAlertIfAvailable()
            }
        case .checking:
            Button("Checking for Updates…") {}
                .disabled(true)
        case .failed:
            Button("Update check failed") {}
                .disabled(true)
        case .upToDate, .idle:
            EmptyView()
        }
    }

    private static let repoURL = URL(string: "https://github.com/ivalkou/rapidkey")!

    private static func showAbout() {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"

        let alert = NSAlert()
        alert.messageText = "RapidKey \(version) (\(build))"
        alert.informativeText = """
            A keyboard-driven command palette for macOS. Press the leader hotkey, \
            then type a key sequence to launch apps, open URLs, or run shell commands \
            defined in ~/.config/rapidkey/rapidkey.toml. \
            See ~/.config/rapidkey/example.toml for full configuration reference.

            \(repoURL.absoluteString)

            Author: Ivan Valkou
            """
        alert.alertStyle = .informational
        if let icon = NSApp.applicationIconImage {
            alert.icon = icon
        }
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "GitHub")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn {
            NSWorkspace.shared.open(repoURL)
        }
    }
}
