import Foundation

/// GUI apps often launch shells without a login profile; ensure UTF-8 for Ruby/CocoaPods and similar tools.
enum ShellProcessEnvironment {
    static let utf8Locale = "en_US.UTF-8"

    private static let cacheLock = NSLock()
    private static var cachedShellPath: String?
    private static var cachedLoginEnvironment: [String: String]?

    static func applyingDefaults(
        shellPath: String,
        to base: [String: String]? = nil
    ) -> [String: String] {
        var env = base
            ?? loginEnvironment(shellPath: shellPath)
            ?? ProcessInfo.processInfo.environment
        env = augmentingPath(env)

        for key in ["LANG", "LC_ALL", "LC_CTYPE"] {
            if needsUTF8Locale(env[key]) {
                env[key] = utf8Locale
            }
        }
        return env
    }

    /// Runs the configured shell as an interactive login shell and captures its environment.
    static func loginEnvironment(shellPath: String) -> [String: String]? {
        cacheLock.lock()
        if cachedShellPath == shellPath, let cachedLoginEnvironment {
            cacheLock.unlock()
            return cachedLoginEnvironment
        }
        cacheLock.unlock()

        guard let captured = captureLoginEnvironment(shellPath: shellPath) else { return nil }

        cacheLock.lock()
        cachedShellPath = shellPath
        cachedLoginEnvironment = captured
        cacheLock.unlock()
        return captured
    }

    private static func captureLoginEnvironment(shellPath: String) -> [String: String]? {
        for arguments in [
            ["-l", "-i", "-c", "env -0"],
            ["-l", "-c", "env -0"],
        ] {
            if let env = runEnvCapture(shellPath: shellPath, arguments: arguments), !env.isEmpty {
                return env
            }
        }
        return nil
    }

    private static func runEnvCapture(shellPath: String, arguments: [String]) -> [String: String]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shellPath)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        let data = (try? pipe.fileHandleForReading.readToEnd()) ?? Data()
        guard !data.isEmpty else { return nil }
        return parseEnvOutput(data)
    }

    private static func parseEnvOutput(_ data: Data) -> [String: String] {
        var env: [String: String] = [:]
        for part in data.split(separator: 0, omittingEmptySubsequences: true) {
            guard let line = String(data: Data(part), encoding: .utf8),
                  let eq = line.firstIndex(of: "=")
            else { continue }
            let key = String(line[..<eq])
            let valueStart = line.index(after: eq)
            env[key] = String(line[valueStart...])
        }
        return env
    }

    /// Fallback when login capture fails: merge common macOS and user bin directories into PATH.
    private static func augmentingPath(_ env: [String: String]) -> [String: String] {
        var env = env
        var seen = Set<String>()
        var dirs: [String] = []

        func append(_ path: String) {
            let trimmed = path.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { return }
            dirs.append(trimmed)
        }

        let existing = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        for part in existing.split(separator: ":", omittingEmptySubsequences: true) {
            append(String(part))
        }

        append("\(NSHomeDirectory())/.local/bin")

        for path in [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/opt/homebrew/sbin",
            "/usr/local/sbin",
        ] {
            append(path)
        }

        env["PATH"] = dirs.joined(separator: ":")
        return env
    }

    private static func needsUTF8Locale(_ value: String?) -> Bool {
        guard let value, !value.isEmpty else { return true }
        let normalized = value.lowercased()
        return !normalized.contains("utf-8") && !normalized.contains("utf8")
    }
}
