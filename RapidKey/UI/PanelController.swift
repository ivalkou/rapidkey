import AppKit
import SwiftUI

final class PanelController: NSWindowController, NSWindowDelegate {
    private let configStore: ConfigStore
    private let state: CommandPaletteState

    init(configStore: ConfigStore) {
        self.configStore = configStore
        self.state = CommandPaletteState(configStore: configStore)
        let rootView = CommandPaletteView(state: state)

        let panel = CommandPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            // `.titled` forces system-rounded window chrome; borderless keeps corners square with our SwiftUI clip.
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true

        let hostingView = NSHostingView(rootView: rootView)
        if #available(macOS 13.0, *) {
            hostingView.sizingOptions = [.minSize, .preferredContentSize]
        }
        panel.contentView = hostingView

        super.init(window: panel)

        panel.delegate = self

        state.onAutoClose = { [weak self] in
            self?.hide()
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
        hide()
    }

    func toggle() {
        guard let panel = window as? CommandPanel else { return }

        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard let panel = window as? CommandPanel else { return }

        state.cancelIdleTimer()
        state.reset(scheduleIdleTimeout: false)
        positionPanel(panel)
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        state.scheduleIdleTimeoutIfNeeded()

        DispatchQueue.main.async { [weak self] in
            guard let self, let panel = self.window as? NSPanel else { return }
            self.positionPanel(panel)
            self.state.scheduleIdleTimeoutIfNeeded()
        }
    }

    func hide() {
        state.cancelIdleTimer()
        window?.orderOut(nil)
    }

    private func positionPanel(_ panel: NSPanel) {
        PanelPositioning.position(panel, using: configStore.config.panel)
    }
}
