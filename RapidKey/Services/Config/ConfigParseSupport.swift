import Foundation

enum ConfigParseSupport {
    static let configPathLabel = "~/.config/rapidkey/rapidkey.toml"

    static func userFacingMessage(detail: String, line: Int?) -> String {
        if let line {
            return "Config error (\(configPathLabel)), line \(line): \(detail)"
        }
        return "Config error (\(configPathLabel)): \(detail)"
    }

    static func makeError(code: Int, detail: String, line: Int?) -> NSError {
        NSError(
            domain: "RapidKey",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: userFacingMessage(detail: detail, line: line)]
        )
    }

    /// Line of a `key = value` or `"key" = ...` assignment (1-based), if found.
    static func lineForKeyAssignment(_ key: String, in source: String) -> Int? {
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

    static func lineForTableHeader(_ header: String, in source: String) -> Int? {
        var lineNo = 0
        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            lineNo += 1
            let t = String(line).trimmingCharacters(in: .whitespaces)
            if t == header { return lineNo }
        }
        return nil
    }
}
