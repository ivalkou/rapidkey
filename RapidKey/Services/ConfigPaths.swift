import Foundation

enum ConfigPaths {
    static var configURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/rapidkey/rapidkey.toml", isDirectory: false)
    }

    static var exampleConfigURL: URL {
        configDirectoryURL.appendingPathComponent("example.toml", isDirectory: false)
    }

    static var configDirectoryURL: URL {
        configURL.deletingLastPathComponent()
    }

    private static let configTemplateHeaderExample = #"""
# RapidKey reference config (~/.config/rapidkey/example.toml)
# Rewritten on every RapidKey launch. Not used by the app — read-only documentation and examples.
# Edit ~/.config/rapidkey/rapidkey.toml to configure RapidKey.

"""#

    private static let configTemplateHeaderUser = #"""
# RapidKey configuration (~/.config/rapidkey/rapidkey.toml)
# Edit this file to configure RapidKey.

"""#

    private static let configTemplateBody: String = {
        guard let url = Bundle.main.url(forResource: "config-body", withExtension: "toml"),
              let body = try? String(contentsOf: url, encoding: .utf8) else {
            fatalError("Missing config-body.toml in app bundle")
        }
        return body
    }()

    /// Reference config with full documentation. Rewritten on every app launch; not read by the app.
    static let exampleConfigToml = configTemplateHeaderExample + configTemplateBody

    /// Starter user config. Written only when rapidkey.toml is missing.
    static let defaultConfigToml = configTemplateHeaderUser + configTemplateBody
}
