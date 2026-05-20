import AppKit

final class DoubleTapModifierMonitor {
    private var tapWindow: TimeInterval = 0.35
    private var minGap: TimeInterval = 0.08
    private var cooldown: TimeInterval = 0.5

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var target: LeaderModifier?
    private var armedForRelease = false
    private var lastTapTime: TimeInterval?
    private var lastFireTime: TimeInterval?

    var onLeader: () -> Void = {}

    /// `true` when the global event monitor was created (Input Monitoring is effective).
    var hasGlobalAccess: Bool { globalMonitor != nil }

    func start(
        modifier: LeaderModifier,
        tapWindow: TimeInterval,
        minGap: TimeInterval,
        cooldown: TimeInterval
    ) {
        stop()
        self.tapWindow = tapWindow
        self.minGap = minGap
        self.cooldown = cooldown
        target = modifier

        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        resetState()
        lastFireTime = nil
        target = nil
    }

    private func handle(_ event: NSEvent) {
        guard let target else { return }

        if event.type == .keyDown {
            resetState()
            return
        }

        guard event.type == .flagsChanged else { return }

        let relevant = Self.relevantModifiers(event.modifierFlags)
        guard let targetFlag = Self.flag(for: target) else { return }

        if relevant == targetFlag {
            armedForRelease = true
        } else if relevant.isEmpty {
            if armedForRelease {
                completeTap()
            }
            armedForRelease = false
        } else {
            resetState()
        }
    }

    private func completeTap() {
        let now = ProcessInfo.processInfo.systemUptime

        if let lastFireTime, now - lastFireTime < cooldown {
            return
        }

        if let lastTapTime, now - lastTapTime <= tapWindow {
            guard now - lastTapTime >= minGap else { return }
            self.lastTapTime = nil
            self.lastFireTime = now
            DispatchQueue.main.async { [weak self] in
                self?.onLeader()
            }
        } else {
            lastTapTime = now
        }
    }

    private func resetState() {
        armedForRelease = false
        lastTapTime = nil
    }

    private static func relevantModifiers(_ flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        flags.intersection([.control, .option, .command, .shift])
    }

    private static func flag(for modifier: LeaderModifier) -> NSEvent.ModifierFlags? {
        switch modifier {
        case .ctrl: .control
        case .alt: .option
        case .cmd: .command
        case .shift: .shift
        }
    }

    deinit {
        stop()
    }
}
