import AppKit
import Combine
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    let configStore = ConfigStore()
    let updateChecker = UpdateChecker()
    private lazy var panelController = PanelController(configStore: configStore)
    private var hotkeyManager: HotkeyManager?
    private var cancellables = Set<AnyCancellable>()
    private var updateCheckTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let hk = HotkeyManager()
        hk.onLeader = { [weak self] in
            self?.showPanel()
        }
        hk.onInputMonitoringRequired = { [weak self] in
            self?.configStore.reportInputMonitoringRequired()
        }
        hk.onInputMonitoringSatisfied = { [weak self] in
            self?.configStore.clearInputMonitoringError()
        }

        hotkeyManager = hk
        hk.apply(config: configStore.config)

        configStore.$config
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak hk] (config: Config) in
                hk?.apply(config: config)
                LaunchAtLoginService.apply(config.launchAtLogin)
                self?.applyUpdateCheckSchedule(interval: config.updateCheckInterval)
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: NSApplication.shared,
            queue: .main
        ) { [weak self] _ in
            self?.reapplyLeaderIfNeeded()
        }
    }

    private func applyUpdateCheckSchedule(interval: TimeInterval?) {
        updateCheckTimer?.invalidate()
        updateCheckTimer = nil

        guard let interval else { return }

        updateChecker.check()

        updateCheckTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateChecker.check()
        }
    }

    func showPanel() {
        panelController.toggle()
    }

    func reapplyLeader() {
        hotkeyManager?.apply(config: configStore.config)
        guard configStore.config.leader.requiresInputMonitoring else { return }
        configStore.clearInputMonitoringErrorIfGranted()
    }

    private func reapplyLeaderIfNeeded() {
        guard configStore.config.leader.requiresInputMonitoring else { return }
        reapplyLeader()
    }
}
