import AppKit
import Foundation

struct RunningAppEntry: Equatable {
    let key: String
    let title: String
    let pid: pid_t
}

enum RunningAppsProvider {
    static let assignmentKeys: [String] = {
        var keys = (1...9).map(String.init) + ["0"]
        keys += "abcdefghijklmnopqrstuvwxyz".map { String($0) }
        return keys
    }()

    static func snapshot() -> [RunningAppEntry] {
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let rapidKeyBundle = Bundle.main.bundleIdentifier

        let apps = NSWorkspace.shared.runningApplications.filter { app in
            guard !app.isTerminated else { return false }
            guard app.activationPolicy == .regular else { return false }
            if let bundleID = app.bundleIdentifier, bundleID == rapidKeyBundle { return false }
            return true
        }

        let sorted = apps.sorted { a, b in
            let aIsFront = a.processIdentifier == frontmostPID
            let bIsFront = b.processIdentifier == frontmostPID
            if aIsFront != bIsFront { return aIsFront }
            let nameA = a.localizedName ?? ""
            let nameB = b.localizedName ?? ""
            return nameA.localizedCaseInsensitiveCompare(nameB) == .orderedAscending
        }

        return zip(sorted.prefix(assignmentKeys.count), assignmentKeys).map { app, key in
            RunningAppEntry(
                key: key,
                title: app.localizedName ?? "Unknown",
                pid: app.processIdentifier
            )
        }
    }

    static func activate(pid: pid_t) {
        guard let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated else { return }
        if app.isHidden {
            app.unhide()
        }

        // Re-open via Launch Services so windowless apps (all windows closed) get a new window,
        // matching dock-click behavior. Falls back to direct activation when bundle URL is missing.
        if let bundleURL = app.bundleURL {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { _, error in
                if error != nil {
                    _ = app.activate(options: [.activateIgnoringOtherApps])
                }
            }
            return
        }

        _ = app.activate(options: [.activateAllWindows])
    }
}
