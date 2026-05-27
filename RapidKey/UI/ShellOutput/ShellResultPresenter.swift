import Foundation

enum ShellResultPresenter {
    static func present(_ payload: ShellResultPayload, panel: PanelConfig) {
        Task { @MainActor in
            ShellResultPanelController.shared.show(payload: payload, panel: panel)
        }
    }

    static func presentStreaming(command: String, panel: PanelConfig) -> ShellResultSession {
        let session = ShellResultSession(command: command)
        ShellResultPanelController.shared.show(session: session, panel: panel)
        return session
    }
}
