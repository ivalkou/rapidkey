import AppKit
import Foundation

enum ActionRunner {
    static func run(_ action: Action, shellPath: String, panel: PanelConfig) {
        switch action.kind {
        case .run(let cmd, let showOutput, let workDir, _):
            ShellExecutor.runDetached(
                command: cmd,
                shellPath: shellPath,
                panel: panel,
                showOutput: showOutput,
                workDir: workDir
            )

        case .open(let name):
            DispatchQueue.main.async {
                ApplicationLauncher.openApplication(named: name)
            }

        case .url(let url):
            DispatchQueue.main.async {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
