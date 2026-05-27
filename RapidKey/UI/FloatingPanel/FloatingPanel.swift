import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

enum FloatingPanelSetup {
    static func makePanel(contentRect: NSRect) -> FloatingPanel {
        let panel = FloatingPanel(
            contentRect: contentRect,
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
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        return panel
    }

    static func makeHostingView<Content: View>(rootView: Content) -> NSHostingView<Content> {
        let hostingView = NSHostingView(rootView: rootView)
        if #available(macOS 13.0, *) {
            hostingView.sizingOptions = [.minSize, .preferredContentSize]
        }
        return hostingView
    }

    static func present(_ panel: FloatingPanel, using panelConfig: PanelConfig) {
        PanelPositioning.position(panel, using: panelConfig)
        PreviousAppFocus.capture()
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.async {
            PanelPositioning.position(panel, using: panelConfig)
        }
    }
}
