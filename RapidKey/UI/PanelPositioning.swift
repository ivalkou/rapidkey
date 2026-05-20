import AppKit

enum PanelPositioning {
    static func screenUnderMouseOrMain() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    static func frameOrigin(
        for position: PanelPosition,
        panelSize: NSSize,
        screen: NSScreen? = nil
    ) -> NSPoint? {
        let screen = screen ?? screenUnderMouseOrMain()
        guard let screen else { return nil }

        let visible = screen.visibleFrame
        switch position {
        case .center:
            return NSPoint(
                x: visible.midX - panelSize.width / 2,
                y: visible.midY - panelSize.height / 2
            )
        case .top:
            let topMargin: CGFloat = 8
            return NSPoint(
                x: visible.midX - panelSize.width / 2,
                y: visible.maxY - panelSize.height - topMargin
            )
        case .bottom:
            let bottomMargin: CGFloat = 8
            return NSPoint(
                x: visible.midX - panelSize.width / 2,
                y: visible.minY + bottomMargin
            )
        case .cursor:
            let mouse = NSEvent.mouseLocation
            let target = NSScreen.screens.first { $0.frame.contains(mouse) } ?? screen
            let v = target.visibleFrame
            let raw = NSPoint(x: mouse.x - panelSize.width / 2, y: mouse.y - panelSize.height + 20)
            return NSPoint(
                x: min(max(raw.x, v.minX + 8), v.maxX - panelSize.width - 8),
                y: min(max(raw.y, v.minY + 8), v.maxY - panelSize.height - 8)
            )
        }
    }

    static func position(_ panel: NSPanel, using panelConfig: PanelConfig) {
        panel.contentView?.layoutSubtreeIfNeeded()
        let size = panel.frame.size
        guard let origin = frameOrigin(for: panelConfig.position, panelSize: size) else { return }
        panel.setFrameOrigin(origin)
    }
}
