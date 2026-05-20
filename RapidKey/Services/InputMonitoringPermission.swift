import AppKit
import CoreGraphics
import IOKit.hid

enum InputMonitoringPermission {
    /// Whether RapidKey can receive global keyboard events (what double-tap needs).
    /// `IOHIDCheckAccess` is unreliable on some macOS versions; probing the actual API is authoritative.
    static var isGranted: Bool {
        canReceiveGlobalEvents
    }

    static var canReceiveGlobalEvents: Bool {
        guard let monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { _ in }) else {
            return false
        }
        NSEvent.removeMonitor(monitor)
        return true
    }

    /// Registers with TCC and prompts only when global listening is not yet available.
    static func request() {
        guard !canReceiveGlobalEvents else { return }

        registerWithTCC()
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard !canReceiveGlobalEvents else { return }
            showFallbackAlert()
        }
    }

    static func openSystemSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private static func registerWithTCC() {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
            userInfo: nil
        )
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
    }

    private static func showFallbackAlert() {
        let alert = NSAlert()
        alert.messageText = "Input Monitoring permission required"
        alert.informativeText = """
            RapidKey needs Input Monitoring to detect a double-tap of a modifier key.

            Open System Settings and enable RapidKey under \
            Privacy & Security → Input Monitoring.
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openSystemSettings()
        }
    }
}
