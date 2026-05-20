import AppKit
import Carbon
import Foundation
import os
import TOMLKit

private let log = Logger(subsystem: "org.soniejka.RapidKey", category: "Config")

enum ConfigLoader {
    private static let configPathLabel = "~/.config/rapidkey/rapidkey.toml"

    private static func userFacingMessage(detail: String, line: Int?) -> String {
        if let line {
            return "Config error (\(configPathLabel)), line \(line): \(detail)"
        }
        return "Config error (\(configPathLabel)): \(detail)"
    }

    private static func makeError(code: Int, detail: String, line: Int?) -> NSError {
        NSError(
            domain: "RapidKey",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: userFacingMessage(detail: detail, line: line)]
        )
    }

    /// Line of a `key = value` or `"key" = ...` assignment (1-based), if found.
    private static func lineForKeyAssignment(_ key: String, in source: String) -> Int? {
        var lineNo = 0
        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            lineNo += 1
            let t = String(line).trimmingCharacters(in: .whitespaces)
            if t.isEmpty || t.hasPrefix("#") { continue }
            if t.hasPrefix("\"\(key)\"") || t.hasPrefix("'\(key)'") { return lineNo }
            if t.hasPrefix("\(key) =") || t.hasPrefix("\(key)=") { return lineNo }
            guard let eq = t.firstIndex(of: "=") else { continue }
            let lhs = t[..<eq].trimmingCharacters(in: .whitespaces)
            if lhs == key || lhs == "\"\(key)\"" || lhs == "'\(key)'" { return lineNo }
        }
        return nil
    }

    private static func lineForTableHeader(_ header: String, in source: String) -> Int? {
        var lineNo = 0
        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            lineNo += 1
            let t = String(line).trimmingCharacters(in: .whitespaces)
            if t == header { return lineNo }
        }
        return nil
    }

    static func parseLeader(_ raw: String) throws -> Leader {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { throw HotkeyParseError.empty }

        if trimmed.hasPrefix("doubletap+") || trimmed.hasPrefix("2tap+") {
            let prefix = trimmed.hasPrefix("doubletap+") ? "doubletap+" : "2tap+"
            let modPart = String(trimmed.dropFirst(prefix.count))
            guard !modPart.isEmpty, !modPart.contains("+") else {
                throw HotkeyParseError.unknownLeader(raw)
            }
            switch modPart {
            case "ctrl", "control": return .doubleTapModifier(.ctrl)
            case "alt", "option": return .doubleTapModifier(.alt)
            case "cmd", "command": return .doubleTapModifier(.cmd)
            case "shift": return .doubleTapModifier(.shift)
            default: throw HotkeyParseError.unknownLeader(raw)
            }
        }

        return try parseChord(trimmed)
    }

    private static func parseChord(_ raw: String) throws -> Leader {
        let parts = raw
            .split(separator: "+", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        guard let last = parts.last else { throw HotkeyParseError.empty }
        guard parts.count >= 1 else { throw HotkeyParseError.empty }

        if parts.count == 1 {
            switch last {
            case "ctrl", "control", "alt", "option", "cmd", "command", "shift":
                throw HotkeyParseError.bareModifierNotAllowed
            default:
                break
            }
        }

        var mods: UInt32 = 0
        for p in parts.dropLast() {
            switch p {
            case "ctrl", "control": mods |= UInt32(controlKey)
            case "alt", "option": mods |= UInt32(optionKey)
            case "cmd", "command": mods |= UInt32(cmdKey)
            case "shift": mods |= UInt32(shiftKey)
            default: throw HotkeyParseError.unknownModifier(p)
            }
        }

        let keyCode = try keyCodeForToken(last)
        return .chord(keyCode: keyCode, modifiers: mods)
    }

    /// US QWERTY virtual key codes (same as `RegisterEventHotKey` / `NSEvent.keyCode`).
    private static func keyCodeForToken(_ token: String) throws -> UInt32 {
        if token.count == 1, let ch = token.first {
            if let vk = PhysicalUSKeyMap.charToVK[ch] { return vk }
            throw HotkeyParseError.unknownKey(token)
        }

        switch token {
        case "space": return 0x31 // kVK_Space
        case "tab": return 0x30
        case "return", "enter": return 0x24
        case "escape", "esc": return 0x35
        case "f1": return 0x7A
        case "f2": return 0x78
        case "f3": return 0x63
        case "f4": return 0x76
        case "f5": return 0x60
        case "f6": return 0x61
        case "f7": return 0x62
        case "f8": return 0x64
        case "f9": return 0x65
        case "f10": return 0x6D
        case "f11": return 0x67
        case "f12": return 0x6F
        default: throw HotkeyParseError.unknownKey(token)
        }
    }

    private static func parseSequenceKey(_ key: String) -> [String] {
        key
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }
            .map { $0.count == 1 ? $0 : $0.lowercased() }
    }

    /// If `path` is a key in `allPaths`, drop any longer path that has `path` as a strict prefix (leaf wins).
    private static func effectiveBindings(raw: [[String]: Action]) -> [[String]: Action] {
        let paths = Set(raw.keys)
        var out: [[String]: Action] = [:]
        for (path, action) in raw {
            let blocked = (1..<path.count).contains { i in
                let prefix = Array(path.prefix(i))
                return paths.contains(prefix)
            }
            if blocked {
                log.warning("Binding \(path.joined(separator: " ")) ignored: shorter binding on prefix wins")
                continue
            }
            out[path] = action
        }
        return out
    }

    private static func parseBindingsTable(_ table: TOMLTable, source: String) throws -> [[String]: Action] {
        var bindings: [[String]: Action] = [:]
        for (key, value) in table {
            let seq = parseSequenceKey(key)
            guard !seq.isEmpty else { continue }

            guard value.type == .table, let inner = value.table else {
                let ln = lineForKeyAssignment(key, in: source)
                throw makeError(
                    code: 1,
                    detail: "In [bindings], key \"\(key)\" must be an inline table `{ title = …, run|open|url = … }`.",
                    line: ln ?? lineForTableHeader("[bindings]", in: source)
                )
            }

            guard let title = inner["title"]?.string, !title.isEmpty else {
                let ln = lineForKeyAssignment(key, in: source)
                throw makeError(
                    code: 2,
                    detail: "Binding \"\(key)\" must have a non-empty title field.",
                    line: ln
                )
            }

            let run = inner["run"]?.string
            let open = inner["open"]?.string
            let urlStr = inner["url"]?.string

            let showOutput: Bool?
            if let conv = inner["show_output"] {
                guard conv.type == .bool, let b = conv.bool else {
                    let ln = lineForKeyAssignment(key, in: source)
                    throw makeError(
                        code: 5,
                        detail: "Binding \"\(key)\": show_output must be a boolean (true/false).",
                        line: ln
                    )
                }
                showOutput = b
            } else {
                showOutput = nil
            }

            let setCount = [run, open, urlStr].compactMap { $0 }.count
            guard setCount == 1 else {
                let ln = lineForKeyAssignment(key, in: source)
                throw makeError(
                    code: 3,
                    detail: "Binding \"\(key)\" must set exactly one of: run, open, or url.",
                    line: ln
                )
            }

            if showOutput != nil, run == nil {
                let ln = lineForKeyAssignment(key, in: source)
                throw makeError(
                    code: 6,
                    detail: "Binding \"\(key)\": show_output is only valid with 'run'.",
                    line: ln
                )
            }

            let workDir = try parseWorkDir(key: key, inner: inner, source: source)

            if workDir != nil, run == nil {
                let ln = lineForKeyAssignment(key, in: source)
                throw makeError(
                    code: 7,
                    detail: "Binding \"\(key)\": work_dir is only valid with 'run'.",
                    line: ln
                )
            }

            let kind: Action.Kind
            if let run {
                kind = .run(run, showOutput: showOutput ?? false, workDir: workDir)
            } else if let open {
                kind = .open(open)
            } else if let urlStr, let url = URL(string: urlStr), url.scheme != nil {
                kind = .url(url)
            } else {
                let ln = lineForKeyAssignment(key, in: source)
                throw makeError(
                    code: 4,
                    detail: "Binding \"\(key)\" has an invalid URL.",
                    line: ln
                )
            }

            bindings[seq] = Action(title: title, kind: kind)
        }
        return bindings
    }

    private static func parseWorkDir(key: String, inner: TOMLTable, source: String) throws -> String? {
        guard let conv = inner["work_dir"] else { return nil }

        guard conv.type == .string, let raw = conv.string, !raw.isEmpty else {
            let ln = lineForKeyAssignment(key, in: source)
            throw makeError(
                code: 8,
                detail: "Binding \"\(key)\": work_dir must be a non-empty string.",
                line: ln
            )
        }

        let expanded = (raw as NSString).expandingTildeInPath
        guard expanded.hasPrefix("/") else {
            let ln = lineForKeyAssignment(key, in: source)
            throw makeError(
                code: 9,
                detail: "Binding \"\(key)\": work_dir must be an absolute path or start with ~ (got \"\(raw)\").",
                line: ln
            )
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory), isDirectory.boolValue else {
            let ln = lineForKeyAssignment(key, in: source)
            throw makeError(
                code: 10,
                detail: "Binding \"\(key)\": work_dir does not exist or is not a directory (\"\(raw)\").",
                line: ln
            )
        }

        return expanded
    }

    private static func parseGroupsTable(_ table: TOMLTable, bindingPaths: Set<[String]>) -> [[String]: String] {
        var groups: [[String]: String] = [:]
        for (key, value) in table {
            guard value.type == .string, let title = value.string, !title.isEmpty else {
                log.warning("[groups] \"\(key)\" must be a non-empty string; skipped")
                continue
            }
            let seq = parseSequenceKey(key)
            guard !seq.isEmpty else { continue }

            let hasDescendant = bindingPaths.contains { path in
                path.count > seq.count && Array(path.prefix(seq.count)) == seq
            }
            if !hasDescendant {
                log.warning("[groups] \"\(key)\" has no bindings under this prefix; ignored")
                continue
            }
            groups[seq] = title
        }
        return groups
    }

    private static func parsePanelPositionString(_ raw: String, source: String, line: Int?) throws -> PanelPosition {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else {
            throw makeError(
                code: 41,
                detail: "position must be a non-empty string.",
                line: line
            )
        }
        guard let pos = PanelPosition(rawValue: s.lowercased()) else {
            throw makeError(
                code: 40,
                detail: "Invalid position: expected one of: center, cursor, top, bottom.",
                line: line
            )
        }
        return pos
    }

    private static func parsePanelTable(_ table: TOMLTable, source: String) throws -> PanelConfig {
        var panel = PanelConfig()
        if let conv = table["position"] {
            guard conv.type == .string, let raw = conv.string else {
                let ln = lineForKeyAssignment("position", in: source)
                throw makeError(
                    code: 41,
                    detail: "In [panel], position must be a non-empty string.",
                    line: ln ?? lineForTableHeader("[panel]", in: source)
                )
            }
            let ln = lineForKeyAssignment("position", in: source)
            panel.position = try parsePanelPositionString(raw, source: source, line: ln)
        }
        return panel
    }

    private static func parseBehaviorTable(_ table: TOMLTable, source: String) throws -> BehaviorConfig {
        var behavior = BehaviorConfig()
        if let conv = table["timeout_ms"] {
            guard conv.type == .int, let ms = conv.int else {
                let ln = lineForKeyAssignment("timeout_ms", in: source)
                throw makeError(
                    code: 43,
                    detail: "In [behavior], timeout_ms must be an integer (milliseconds).",
                    line: ln ?? lineForTableHeader("[behavior]", in: source)
                )
            }
            guard ms >= 0 else {
                let ln = lineForKeyAssignment("timeout_ms", in: source)
                throw makeError(
                    code: 44,
                    detail: "timeout_ms cannot be negative.",
                    line: ln
                )
            }
            behavior.idleTimeout = ms == 0 ? nil : TimeInterval(ms) / 1000.0
        }
        if let conv = table["double_tap_ms"] {
            guard conv.type == .int, let ms = conv.int else {
                let ln = lineForKeyAssignment("double_tap_ms", in: source)
                throw makeError(
                    code: 48,
                    detail: "In [behavior], double_tap_ms must be an integer (milliseconds).",
                    line: ln ?? lineForTableHeader("[behavior]", in: source)
                )
            }
            guard ms > 0 else {
                let ln = lineForKeyAssignment("double_tap_ms", in: source)
                throw makeError(
                    code: 49,
                    detail: "double_tap_ms must be greater than 0.",
                    line: ln
                )
            }
            behavior.doubleTapWindow = TimeInterval(ms) / 1000.0
        }
        return behavior
    }

    private static func parseShell(_ root: TOMLTable, source: String) throws -> String {
        let line = lineForKeyAssignment("shell", in: source)
        let raw: String
        if let conv = root["shell"] {
            guard conv.type == .string, let value = conv.string, !value.isEmpty else {
                throw makeError(
                    code: 47,
                    detail: "shell must be a non-empty string.",
                    line: line
                )
            }
            raw = value
        } else {
            raw = "sh"
        }
        return try resolveShell(raw, line: root["shell"] != nil ? line : nil)
    }

    private static func resolveShell(_ raw: String, line: Int?) throws -> String {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.contains("/") || name.hasPrefix("~") {
            let path = (name as NSString).expandingTildeInPath
            guard FileManager.default.isExecutableFile(atPath: path) else {
                throw makeError(
                    code: 48,
                    detail: "shell is not executable or does not exist (\"\(raw)\").",
                    line: line
                )
            }
            return path
        }

        for dir in shellSearchDirectories() {
            let candidate = URL(fileURLWithPath: dir)
                .appendingPathComponent(name)
                .path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        throw makeError(
            code: 49,
            detail: "shell \"\(raw)\" not found in PATH.",
            line: line
        )
    }

    /// GUI apps often inherit a minimal PATH; include common macOS and user locations.
    private static func shellSearchDirectories() -> [String] {
        var seen = Set<String>()
        var dirs: [String] = []

        func append(_ path: String) {
            let trimmed = path.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { return }
            dirs.append(trimmed)
        }

        let envPath = ProcessInfo.processInfo.environment["PATH"]
            ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        for part in envPath.split(separator: ":", omittingEmptySubsequences: true) {
            append(String(part))
        }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        append("\(home)/.local/bin")

        for path in [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/opt/homebrew/sbin",
            "/usr/local/sbin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
        ] {
            append(path)
        }

        return dirs
    }

    private static func parseLaunchAtLogin(_ root: TOMLTable, source: String) throws -> Bool {
        guard let conv = root["launch_at_login"] else { return false }
        guard conv.type == .bool, let b = conv.bool else {
            let ln = lineForKeyAssignment("launch_at_login", in: source)
            throw makeError(
                code: 45,
                detail: "launch_at_login must be a boolean (true/false).",
                line: ln
            )
        }
        return b
    }

    private static func parseConfigFromTOML(_ root: TOMLTable, source: String) throws -> Config {
        guard let leaderStr = root["leader"]?.string, !leaderStr.isEmpty else {
            let ln = lineForKeyAssignment("leader", in: source)
            throw makeError(
                code: 10,
                detail: "leader is missing or empty (global shortcut to open the panel).",
                line: ln
            )
        }

        let leader: Leader
        do {
            leader = try parseLeader(leaderStr)
        } catch let e as HotkeyParseError {
            let ln = lineForKeyAssignment("leader", in: source)
            let detail = e.errorDescription ?? String(describing: e)
            throw makeError(code: 11, detail: "Invalid leader: \(detail)", line: ln)
        }

        guard let bindingsTable = root["bindings"]?.table else {
            let ln = lineForTableHeader("[bindings]", in: source)
            throw makeError(
                code: 12,
                detail: "Missing [bindings] section with a bindings table.",
                line: ln
            )
        }

        let rawBindings = try parseBindingsTable(bindingsTable, source: source)
        let bindings = effectiveBindings(raw: rawBindings)
        let bindingPaths = Set(bindings.keys)

        let groupTitles: [[String]: String]
        if let g = root["groups"]?.table {
            groupTitles = parseGroupsTable(g, bindingPaths: bindingPaths)
        } else {
            groupTitles = [:]
        }

        let panel: PanelConfig
        if let conv = root["panel"] {
            guard conv.type == .table, let t = conv.table else {
                let ln = lineForTableHeader("[panel]", in: source)
                throw makeError(
                    code: 42,
                    detail: "The [panel] section must be a TOML table.",
                    line: ln
                )
            }
            panel = try parsePanelTable(t, source: source)
        } else {
            panel = PanelConfig()
        }

        let behavior: BehaviorConfig
        if let conv = root["behavior"] {
            guard conv.type == .table, let t = conv.table else {
                let ln = lineForTableHeader("[behavior]", in: source)
                throw makeError(
                    code: 46,
                    detail: "The [behavior] section must be a TOML table.",
                    line: ln
                )
            }
            behavior = try parseBehaviorTable(t, source: source)
        } else {
            behavior = BehaviorConfig()
        }

        let launchAtLogin = try parseLaunchAtLogin(root, source: source)
        let shellPath = try parseShell(root, source: source)

        return Config(
            leader: leader,
            bindings: bindings,
            groupTitles: groupTitles,
            panel: panel,
            behavior: behavior,
            launchAtLogin: launchAtLogin,
            shellPath: shellPath
        )
    }

    static func loadConfigFromDisk() throws -> Config {
        let url = ConfigPaths.configURL
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw makeError(
                code: 19,
                detail: "Could not read the file (\(error.localizedDescription)).",
                line: nil
            )
        }

        guard let source = String(data: data, encoding: .utf8) else {
            throw makeError(code: 20, detail: "The file is not valid UTF-8.", line: nil)
        }

        let root: TOMLTable
        do {
            root = try TOMLTable(string: source)
        } catch let parseError as TOMLParseError {
            let line = parseError.source.begin.line
            throw makeError(code: 30, detail: parseError.description, line: line)
        }

        return try parseConfigFromTOML(root, source: source)
    }
}
