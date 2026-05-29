import AppKit
import SwiftUI

struct MenuBarContent: View {
    let appDelegate: AppDelegate
    @ObservedObject var configStore: ConfigStore

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

        Button("About RapidKey") {
            Self.showAbout()
        }

        Button("Quit") {
            NSApplication.shared.terminate(nil)
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
