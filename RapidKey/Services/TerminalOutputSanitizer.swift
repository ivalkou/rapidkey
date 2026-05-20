import Foundation

enum TerminalOutputSanitizer {
    private static let ansiEscape = try! Regex(#"\u{001B}(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])"#)

    static func strippingANSI(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        return text.replacing(ansiEscape, with: "")
    }
}
