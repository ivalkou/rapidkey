import Combine
import Foundation
import os

private let log = Logger(subsystem: "org.soniejka.RapidKey", category: "Config")

private final class ConfigReloadSink {
    weak var store: ConfigStore?

    func fire() {
        store?.reload()
    }
}

final class ConfigStore: ObservableObject {
    @Published private(set) var config: Config
    @Published private(set) var lastError: String?

    private var lastGood: Config
    private let reloadSink = ConfigReloadSink()
    private let configWatcher: ConfigFileWatcher

    init() {
        Self.ensureDefaultExists()
        let initial = (try? ConfigLoader.loadConfigFromDisk()) ?? Self.emergencyFallback()
        self.config = initial
        self.lastGood = initial
        self.lastError = nil

        let sink = reloadSink
        self.configWatcher = ConfigFileWatcher(url: ConfigPaths.configURL) {
            sink.fire()
        }
        sink.store = self
        self.configWatcher.start()
    }

    private static func emergencyFallback() -> Config {
        let leader = try! ConfigLoader.parseLeader("alt+space")
        return Config(leader: leader, bindings: [:], groupTitles: [:])
    }

    static func ensureDefaultExists() {
        let url = ConfigPaths.configURL
        let dir = ConfigPaths.configDirectoryURL
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? ConfigPaths.defaultConfigToml.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func reportInputMonitoringRequired() {
        let apply: () -> Void = { [weak self] in
            guard let self else { return }
            self.lastError = """
                Leader requires Input Monitoring. Enable RapidKey in \
                System Settings -> Privacy & Security -> Input Monitoring.
                """
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    func clearInputMonitoringError() {
        let apply: () -> Void = { [weak self] in
            guard let self, self.lastError?.contains("Input Monitoring") == true else { return }
            self.lastError = nil
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    func clearInputMonitoringErrorIfGranted() {
        guard InputMonitoringPermission.isGranted else { return }
        clearInputMonitoringError()
    }

    func reload() {
        let apply: () -> Void = { [weak self] in
            guard let self else { return }
            do {
                let url = ConfigPaths.configURL
                if !FileManager.default.fileExists(atPath: url.path) {
                    Self.ensureDefaultExists()
                }
                let next = try ConfigLoader.loadConfigFromDisk()
                self.config = next
                self.lastGood = next
                self.lastError = nil
            } catch {
                log.error("Config reload failed: \(String(describing: error))")
                self.lastError = error.localizedDescription
            }
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }
}
