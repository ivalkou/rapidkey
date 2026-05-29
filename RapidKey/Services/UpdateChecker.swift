import AppKit
import Combine
import Foundation
import os

private let log = Logger(subsystem: "org.soniejka.RapidKey", category: "UpdateChecker")

enum VersionComparison {
    /// Returns true when `candidate` is strictly newer than `current`.
    static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        compare(parse(candidate), parse(current)) == .orderedDescending
    }

    private static func parse(_ raw: String) -> [Int] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutPrefix = trimmed.hasPrefix("v") || trimmed.hasPrefix("V")
            ? String(trimmed.dropFirst())
            : trimmed
        return withoutPrefix.split(separator: ".").map { part in
            Int(part.trimmingCharacters(in: .whitespaces)) ?? 0
        }
    }

    private static func compare(_ lhs: [Int], _ rhs: [Int]) -> ComparisonResult {
        let count = max(lhs.count, rhs.count)
        for index in 0..<count {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left < right { return .orderedAscending }
            if left > right { return .orderedDescending }
        }
        return .orderedSame
    }
}

@MainActor
final class UpdateChecker: ObservableObject {
    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case updateAvailable(version: String, url: URL)
        case failed(String)
    }

    @Published private(set) var status: Status = .idle

    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/ivalkou/rapidkey/releases/latest")!
    private static let brewUpgradeCommand = "brew update && brew upgrade --cask ivalkou/tap/rapidkey"

    private var checkTask: Task<Void, Never>?

    func check(manual: Bool = false) {
        guard status != .checking else { return }

        checkTask?.cancel()
        status = .checking

        checkTask = Task { [weak self] in
            await self?.performCheck(manual: manual)
        }
    }

    private func performCheck(manual: Bool) async {
        do {
            var request = URLRequest(url: Self.latestReleaseURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("RapidKey", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled else { return }

            guard let http = response as? HTTPURLResponse else {
                status = .failed("Invalid response")
                return
            }
            guard (200..<300).contains(http.statusCode) else {
                status = .failed("HTTP \(http.statusCode)")
                return
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            guard !Task.isCancelled else { return }

            let latestVersion = release.tagName
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"

            if VersionComparison.isVersion(latestVersion, newerThan: currentVersion),
               let url = URL(string: release.htmlURL) {
                status = .updateAvailable(version: normalizeVersion(latestVersion), url: url)
            } else {
                status = .upToDate
                if manual {
                    Self.presentUpToDateAlert(currentVersion: currentVersion)
                }
            }
        } catch {
            guard !Task.isCancelled else { return }
            log.error("Update check failed: \(String(describing: error))")
            status = .failed(error.localizedDescription)
        }
    }

    func presentUpdateAlertIfAvailable() {
        guard case .updateAvailable(let version, let url) = status else { return }
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        Self.presentUpdateAlert(version: version, currentVersion: currentVersion, url: url)
    }

    private static func presentUpToDateAlert(currentVersion: String) {
        let alert = NSAlert()
        alert.messageText = "You're up to date"
        alert.informativeText = "RapidKey v\(currentVersion) is the latest version."
        alert.alertStyle = .informational
        if let icon = NSApp.applicationIconImage {
            alert.icon = icon
        }
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private static func presentUpdateAlert(version: String, currentVersion: String, url: URL) {
        let alert = NSAlert()
        alert.messageText = "Update Available: v\(version)"
        alert.informativeText = """
            You're running RapidKey v\(currentVersion). Version v\(version) is available.

            Upgrade with Homebrew (recommended) or download the release from GitHub.
            """
        alert.alertStyle = .informational
        if let icon = NSApp.applicationIconImage {
            alert.icon = icon
        }
        alert.addButton(withTitle: "Later")
        alert.addButton(withTitle: "GitHub Release")
        alert.addButton(withTitle: "Upgrade with Homebrew")

        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertSecondButtonReturn:
            NSWorkspace.shared.open(url)
        case .alertThirdButtonReturn:
            runBrewUpgradeInTerminal()
        default:
            break
        }
    }

    private static func runBrewUpgradeInTerminal() {
        let command = brewUpgradeCommand
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
            tell application "Terminal"
                activate
                do script "\(escaped)"
            end tell
            """
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        if error != nil {
            log.error("Failed to open Terminal for brew upgrade")
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: .string)
        }
    }

    private func normalizeVersion(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("v") || trimmed.hasPrefix("V") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}
