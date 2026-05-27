import AppKit
import SwiftUI

final class PanelController: NSWindowController, NSWindowDelegate {
    private let configStore: ConfigStore
    private let state: CommandPaletteState

    init(configStore: ConfigStore) {
        self.configStore = configStore
        self.state = CommandPaletteState(configStore: configStore)
        let rootView = CommandPaletteView(state: state)

        let panel = FloatingPanelSetup.makePanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320)
        )
        panel.contentView = FloatingPanelSetup.makeHostingView(rootView: rootView)

        super.init(window: panel)

        panel.delegate = self

        state.onAutoClose = { [weak self] in
            self?.hide(restoreFocus: true)
        }
        state.onDismiss = { [weak self] restoreFocus, discardSavedFocus in
            self?.hide(restoreFocus: restoreFocus, discardSavedFocus: discardSavedFocus)
        }
        state.isPanelKeyAndVisible = { [weak self] in
            guard let w = self?.window as? NSPanel else { return false }
            return w.isVisible && w.isKeyWindow
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowDidResignKey(_ notification: Notification) {
        hide(restoreFocus: true)
    }

    func toggle() {
        guard let panel = window as? FloatingPanel else { return }

        if panel.isVisible {
            hide(restoreFocus: true)
        } else {
            show()
        }
    }

    func show() {
        guard let panel = window as? FloatingPanel else { return }

        state.cancelIdleTimer()
        state.reset(scheduleIdleTimeout: false)
        FloatingPanelSetup.present(panel, using: configStore.config.panel)
        state.scheduleIdleTimeoutIfNeeded()

        DispatchQueue.main.async { [weak self] in
            self?.state.scheduleIdleTimeoutIfNeeded()
        }
    }

    func hide(restoreFocus: Bool = true, discardSavedFocus: Bool = false) {
        state.cancelIdleTimer()
        window?.orderOut(nil)
        if restoreFocus {
            PreviousAppFocus.restoreIfRapidKeyStillFrontmost()
        } else if discardSavedFocus {
            PreviousAppFocus.discard()
        }
    }
}
