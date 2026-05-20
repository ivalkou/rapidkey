import AppKit
import Foundation

enum ApplicationLauncher {
    static func openApplication(named name: String) {
        let configuration = NSWorkspace.OpenConfiguration()

        if name == "Finder",
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.finder") {
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
                if let error {
                    fputs("RapidKey: open Finder failed: \(error)\n", Darwin.stderr)
                }
            }
            return
        }

        let appFolder = name.hasSuffix(".app") ? name : "\(name).app"
        let directPaths = [
            "/Applications/\(appFolder)",
            "/Applications/Utilities/\(appFolder)",
            "/System/Applications/\(appFolder)",
            "/System/Applications/Utilities/\(appFolder)",
        ]
        for path in directPaths {
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
                if let error {
                    fputs("RapidKey: open \(path) failed: \(error)\n", Darwin.stderr)
                }
            }
            return
        }

        // Fallback: delegate to LaunchServices via `open -a`, which finds apps anywhere
        // (Utilities, ~/Applications, third-party install locations, etc.).
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", name]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            fputs("RapidKey: application not found: \(name) (open -a failed: \(error))\n", Darwin.stderr)
        }
    }
}
