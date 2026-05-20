import AppKit

@MainActor
enum PreviousAppFocus {
    private static var saved: NSRunningApplication?

    static func capture() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier
        else {
            saved = nil
            return
        }
        saved = app
    }

    static func restoreIfRapidKeyStillFrontmost() {
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
        else {
            saved = nil
            return
        }
        saved?.activate(options: [])
        saved = nil
    }

    static func discard() {
        saved = nil
    }
}
