import AppKit
import Foundation

enum AppIconProvider {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(for ref: PaletteAppIconRef) -> NSImage? {
        switch ref {
        case .applicationName(let name):
            return icon(forApplicationName: name)
        case .processID(let pid):
            return icon(forPID: pid)
        }
    }

    private static func icon(forApplicationName name: String) -> NSImage? {
        let cacheKey = "app:\(name)" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        if name == "Finder",
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.finder") {
            return store(NSWorkspace.shared.icon(forFile: url.path), key: cacheKey)
        }

        let appFolder = name.hasSuffix(".app") ? name : "\(name).app"
        let searchPaths = [
            "/Applications/\(appFolder)",
            "/Applications/Utilities/\(appFolder)",
            "/System/Applications/\(appFolder)",
            "/System/Applications/Utilities/\(appFolder)",
        ]
        for path in searchPaths where FileManager.default.fileExists(atPath: path) {
            return store(NSWorkspace.shared.icon(forFile: path), key: cacheKey)
        }

        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: name) {
            return store(NSWorkspace.shared.icon(forFile: url.path), key: cacheKey)
        }

        return nil
    }

    private static func icon(forPID pid: pid_t) -> NSImage? {
        let cacheKey = "pid:\(pid)" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }
        guard let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated else {
            return nil
        }
        guard let icon = app.icon else { return nil }
        return store(icon, key: cacheKey)
    }

    private static func store(_ icon: NSImage, key: NSString) -> NSImage {
        cache.setObject(icon, forKey: key)
        return icon
    }
}
