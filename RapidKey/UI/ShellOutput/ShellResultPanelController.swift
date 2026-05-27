import AppKit
import SwiftUI

@MainActor
final class ShellResultPanelController: NSObject, NSWindowDelegate {
    static let shared = ShellResultPanelController()

    private var panel: FloatingPanel?
    private var keyMonitor: Any?
    private var session: ShellResultSession?
    private var panelConfig = PanelConfig()

    func show(payload: ShellResultPayload, panel panelConfig: PanelConfig) {
        show(session: ShellResultSession.finished(from: payload), panel: panelConfig)
    }

    func show(session: ShellResultSession, panel panelConfig: PanelConfig) {
        dismissPanel(restoreFocus: false)

        self.session = session
        self.panelConfig = panelConfig
        let view = ShellResultView(session: session) { [weak self] in
            self?.hide()
        }

        let p = FloatingPanelSetup.makePanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 440)
        )
        p.contentView = FloatingPanelSetup.makeHostingView(rootView: view)
        p.delegate = self

        panel = p
        FloatingPanelSetup.present(p, using: panelConfig)

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let panel = self.panel, event.window === panel else { return event }
            if event.keyCode == 0x35 {
                self.hide()
                return nil
            }
            if event.modifierFlags.contains(.control),
               event.keyCode == 0x08,
               self.session?.canCancel == true {
                self.session?.requestCancel()
                return nil
            }
            return event
        }
    }

    func hide() {
        dismissPanel(restoreFocus: true)
    }

    private func dismissPanel(restoreFocus: Bool) {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        panel?.orderOut(nil)
        panel = nil
        session = nil
        if restoreFocus {
            PreviousAppFocus.restoreIfRapidKeyStillFrontmost()
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        guard session?.isRunning != true else { return }
        hide()
    }
}
