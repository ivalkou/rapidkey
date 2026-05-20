import Foundation

private enum HotkeyID {
    static let leader: UInt32 = 1
}

final class HotkeyManager {
    private let chordRegistrar = ChordRegistrar()
    private let doubleTapMonitor = DoubleTapModifierMonitor()
    private var didRequestInputMonitoring = false

    var onLeader: () -> Void = {}
    var onInputMonitoringRequired: () -> Void = {}
    var onInputMonitoringSatisfied: () -> Void = {}

    init() {}

    func apply(config: Config) {
        tearDown()

        switch config.leader {
        case .chord(let keyCode, let modifiers):
            didRequestInputMonitoring = false
            chordRegistrar.register(
                id: HotkeyID.leader,
                keyCode: keyCode,
                modifiers: modifiers,
                handler: { [weak self] in self?.fireLeader() }
            )
            onInputMonitoringSatisfied()

        case .doubleTapModifier(let modifier):
            doubleTapMonitor.onLeader = { [weak self] in self?.fireLeader() }
            doubleTapMonitor.start(
                modifier: modifier,
                tapWindow: config.behavior.doubleTapWindow,
                minGap: config.behavior.doubleTapMinGap,
                cooldown: config.behavior.doubleTapCooldown
            )

            if doubleTapMonitor.hasGlobalAccess {
                didRequestInputMonitoring = false
                onInputMonitoringSatisfied()
            } else {
                if !didRequestInputMonitoring {
                    didRequestInputMonitoring = true
                    InputMonitoringPermission.request()
                }
                onInputMonitoringRequired()
            }
        }
    }

    private func fireLeader() {
        DispatchQueue.main.async { [weak self] in
            self?.onLeader()
        }
    }

    private func tearDown() {
        doubleTapMonitor.stop()
        chordRegistrar.unregisterAll()
    }

    deinit {
        tearDown()
    }
}
