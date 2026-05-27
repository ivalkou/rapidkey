import AppKit
import Foundation
import os
import TOMLKit

private let log = Logger(subsystem: "org.soniejka.RapidKey", category: "Config")

enum ConfigLoader {
    static func parseLeader(_ raw: String) throws -> Leader {
        try LeaderParser.parseLeader(raw)
    }

    private static func parseSequenceKey(_ key: String) -> [String] {
        key
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }
            .map { PhysicalUSKeyMap.normalizeBindingToken($0) }
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

            for token in seq {
                guard PhysicalUSKeyMap.isKnownToken(token) else {
                    let ln = ConfigParseSupport.lineForKeyAssignment(key, in: source)
                    throw ConfigParseSupport.makeError(
                        code: 8,
                        detail: "Binding \"\(key)\": unknown key token \"\(token)\".",
                        line: ln
                    )
                }
            }

            guard value.type == .table, let inner = value.table else {
                let ln = ConfigParseSupport.lineForKeyAssignment(key, in: source)
                throw ConfigParseSupport.makeError(
                    code: 1,
                    detail: "In [bindings], key \"\(key)\" must be an inline table `{ title = …, run|open|url = … }`.",
                    line: ln ?? ConfigParseSupport.lineForTableHeader("[bindings]", in: source)
                )
            }

            guard let title = inner["title"]?.string, !title.isEmpty else {
                let ln = ConfigParseSupport.lineForKeyAssignment(key, in: source)
                throw ConfigParseSupport.makeError(
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
                    let ln = ConfigParseSupport.lineForKeyAssignment(key, in: source)
                    throw ConfigParseSupport.makeError(
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
                let ln = ConfigParseSupport.lineForKeyAssignment(key, in: source)
                throw ConfigParseSupport.makeError(
                    code: 3,
                    detail: "Binding \"\(key)\" must set exactly one of: run, open, or url.",
                    line: ln
                )
            }

            if showOutput != nil, run == nil {
                let ln = ConfigParseSupport.lineForKeyAssignment(key, in: source)
                throw ConfigParseSupport.makeError(
                    code: 6,
                    detail: "Binding \"\(key)\": show_output is only valid with 'run'.",
                    line: ln
                )
            }

            let workDir = try parseWorkDir(key: key, inner: inner, source: source)
            let confirmMessage = try parseConfirm(key: key, title: title, inner: inner, source: source, run: run)

            if confirmMessage != nil, run == nil {
                let ln = ConfigParseSupport.lineForKeyAssignment(key, in: source)
                throw ConfigParseSupport.makeError(
                    code: 11,
                    detail: "Binding \"\(key)\": confirm is only valid with 'run'.",
                    line: ln
                )
            }

            if workDir != nil, run == nil {
                let ln = ConfigParseSupport.lineForKeyAssignment(key, in: source)
                throw ConfigParseSupport.makeError(
                    code: 7,
                    detail: "Binding \"\(key)\": work_dir is only valid with 'run'.",
                    line: ln
                )
            }

            let kind: Action.Kind
            if let run {
                kind = .run(run, showOutput: showOutput ?? false, workDir: workDir, confirmMessage: confirmMessage)
            } else if let open {
                kind = .open(open)
            } else if let urlStr, let url = URL(string: urlStr), url.scheme != nil {
                kind = .url(url)
            } else {
                let ln = ConfigParseSupport.lineForKeyAssignment(key, in: source)
                throw ConfigParseSupport.makeError(
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
            let ln = ConfigParseSupport.lineForKeyAssignment(key, in: source)
            throw ConfigParseSupport.makeError(
                code: 8,
                detail: "Binding \"\(key)\": work_dir must be a non-empty string.",
                line: ln
            )
        }

        let expanded = (raw as NSString).expandingTildeInPath
        guard expanded.hasPrefix("/") else {
            let ln = ConfigParseSupport.lineForKeyAssignment(key, in: source)
            throw ConfigParseSupport.makeError(
                code: 9,
                detail: "Binding \"\(key)\": work_dir must be an absolute path or start with ~ (got \"\(raw)\").",
                line: ln
            )
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory), isDirectory.boolValue else {
            let ln = ConfigParseSupport.lineForKeyAssignment(key, in: source)
            throw ConfigParseSupport.makeError(
                code: 10,
                detail: "Binding \"\(key)\": work_dir does not exist or is not a directory (\"\(raw)\").",
                line: ln
            )
        }

        return expanded
    }

    private static func parseConfirm(
        key: String,
        title: String,
        inner: TOMLTable,
        source: String,
        run: String?
    ) throws -> String? {
        guard let conv = inner["confirm"] else { return nil }

        if conv.type == .bool {
            guard let enabled = conv.bool else {
                let ln = ConfigParseSupport.lineForKeyAssignment(key, in: source)
                throw ConfigParseSupport.makeError(
                    code: 12,
                    detail: "Binding \"\(key)\": confirm must be a boolean or non-empty string.",
                    line: ln
                )
            }
            return enabled ? title : nil
        }

        if conv.type == .string, let message = conv.string, !message.isEmpty {
            return message
        }

        let ln = ConfigParseSupport.lineForKeyAssignment(key, in: source)
        throw ConfigParseSupport.makeError(
            code: 12,
            detail: "Binding \"\(key)\": confirm must be a boolean or non-empty string.",
            line: ln
        )
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
            throw ConfigParseSupport.makeError(
                code: 41,
                detail: "position must be a non-empty string.",
                line: line
            )
        }
        guard let pos = PanelPosition(rawValue: s.lowercased()) else {
            throw ConfigParseSupport.makeError(
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
                let ln = ConfigParseSupport.lineForKeyAssignment("position", in: source)
                throw ConfigParseSupport.makeError(
                    code: 41,
                    detail: "In [panel], position must be a non-empty string.",
                    line: ln ?? ConfigParseSupport.lineForTableHeader("[panel]", in: source)
                )
            }
            let ln = ConfigParseSupport.lineForKeyAssignment("position", in: source)
            panel.position = try parsePanelPositionString(raw, source: source, line: ln)
        }
        if let conv = table["show_app_icons"] {
            guard conv.type == .bool, let show = conv.bool else {
                let ln = ConfigParseSupport.lineForKeyAssignment("show_app_icons", in: source)
                throw ConfigParseSupport.makeError(
                    code: 43,
                    detail: "In [panel], show_app_icons must be a boolean (true/false).",
                    line: ln ?? ConfigParseSupport.lineForTableHeader("[panel]", in: source)
                )
            }
            panel.showAppIcons = show
        }
        return panel
    }

    private static func parsePositiveBehaviorMs(
        _ conv: TOMLValueConvertible,
        key: String,
        source: String,
        invalidTypeCode: Int,
        nonPositiveCode: Int
    ) throws -> TimeInterval {
        guard conv.type == .int, let ms = conv.int else {
            let ln = ConfigParseSupport.lineForKeyAssignment(key, in: source)
            throw ConfigParseSupport.makeError(
                code: invalidTypeCode,
                detail: "In [behavior], \(key) must be an integer (milliseconds).",
                line: ln ?? ConfigParseSupport.lineForTableHeader("[behavior]", in: source)
            )
        }
        guard ms > 0 else {
            let ln = ConfigParseSupport.lineForKeyAssignment(key, in: source)
            throw ConfigParseSupport.makeError(
                code: nonPositiveCode,
                detail: "\(key) must be greater than 0.",
                line: ln
            )
        }
        return TimeInterval(ms) / 1000.0
    }

    private static func parseBehaviorTable(_ table: TOMLTable, source: String) throws -> BehaviorConfig {
        var behavior = BehaviorConfig()
        if let conv = table["timeout_ms"] {
            guard conv.type == .int, let ms = conv.int else {
                let ln = ConfigParseSupport.lineForKeyAssignment("timeout_ms", in: source)
                throw ConfigParseSupport.makeError(
                    code: 43,
                    detail: "In [behavior], timeout_ms must be an integer (milliseconds).",
                    line: ln ?? ConfigParseSupport.lineForTableHeader("[behavior]", in: source)
                )
            }
            guard ms >= 0 else {
                let ln = ConfigParseSupport.lineForKeyAssignment("timeout_ms", in: source)
                throw ConfigParseSupport.makeError(
                    code: 44,
                    detail: "timeout_ms cannot be negative.",
                    line: ln
                )
            }
            behavior.idleTimeout = ms == 0 ? nil : TimeInterval(ms) / 1000.0
        }
        if let conv = table["double_tap_ms"] {
            behavior.doubleTapWindow = try parsePositiveBehaviorMs(
                conv,
                key: "double_tap_ms",
                source: source,
                invalidTypeCode: 48,
                nonPositiveCode: 49
            )
        }
        if let conv = table["double_tap_min_ms"] {
            behavior.doubleTapMinGap = try parsePositiveBehaviorMs(
                conv,
                key: "double_tap_min_ms",
                source: source,
                invalidTypeCode: 50,
                nonPositiveCode: 51
            )
        }
        if let conv = table["double_tap_cooldown_ms"] {
            behavior.doubleTapCooldown = try parsePositiveBehaviorMs(
                conv,
                key: "double_tap_cooldown_ms",
                source: source,
                invalidTypeCode: 52,
                nonPositiveCode: 53
            )
        }
        if behavior.doubleTapMinGap > behavior.doubleTapWindow {
            let ln = ConfigParseSupport.lineForKeyAssignment("double_tap_min_ms", in: source)
                ?? ConfigParseSupport.lineForKeyAssignment("double_tap_ms", in: source)
            throw ConfigParseSupport.makeError(
                code: 54,
                detail: "double_tap_min_ms cannot be greater than double_tap_ms.",
                line: ln
            )
        }
        return behavior
    }

    private static func parseShell(_ root: TOMLTable, source: String) throws -> String {
        let line = ConfigParseSupport.lineForKeyAssignment("shell", in: source)
        let raw: String
        if let conv = root["shell"] {
            guard conv.type == .string, let value = conv.string, !value.isEmpty else {
                throw ConfigParseSupport.makeError(
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
                throw ConfigParseSupport.makeError(
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

        throw ConfigParseSupport.makeError(
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
            let ln = ConfigParseSupport.lineForKeyAssignment("launch_at_login", in: source)
            throw ConfigParseSupport.makeError(
                code: 45,
                detail: "launch_at_login must be a boolean (true/false).",
                line: ln
            )
        }
        return b
    }

    private static func parseConfigFromTOML(_ root: TOMLTable, source: String) throws -> Config {
        guard let leaderStr = root["leader"]?.string, !leaderStr.isEmpty else {
            let ln = ConfigParseSupport.lineForKeyAssignment("leader", in: source)
            throw ConfigParseSupport.makeError(
                code: 10,
                detail: "leader is missing or empty (global shortcut to open the panel).",
                line: ln
            )
        }

        let leader: Leader
        do {
            leader = try LeaderParser.parseLeader(leaderStr)
        } catch let e as HotkeyParseError {
            let ln = ConfigParseSupport.lineForKeyAssignment("leader", in: source)
            let detail = e.errorDescription ?? String(describing: e)
            throw ConfigParseSupport.makeError(code: 11, detail: "Invalid leader: \(detail)", line: ln)
        }

        guard let bindingsTable = root["bindings"]?.table else {
            let ln = ConfigParseSupport.lineForTableHeader("[bindings]", in: source)
            throw ConfigParseSupport.makeError(
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
                let ln = ConfigParseSupport.lineForTableHeader("[panel]", in: source)
                throw ConfigParseSupport.makeError(
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
                let ln = ConfigParseSupport.lineForTableHeader("[behavior]", in: source)
                throw ConfigParseSupport.makeError(
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
            throw ConfigParseSupport.makeError(
                code: 19,
                detail: "Could not read the file (\(error.localizedDescription)).",
                line: nil
            )
        }

        guard let source = String(data: data, encoding: .utf8) else {
            throw ConfigParseSupport.makeError(code: 20, detail: "The file is not valid UTF-8.", line: nil)
        }

        let root: TOMLTable
        do {
            root = try TOMLTable(string: source)
        } catch let parseError as TOMLParseError {
            let line = parseError.source.begin.line
            throw ConfigParseSupport.makeError(code: 30, detail: parseError.description, line: line)
        }

        return try parseConfigFromTOML(root, source: source)
    }
}
