import Foundation

enum PanelPosition: String, Equatable {
    case center
    case cursor
    case top
    case bottom
}

struct PanelConfig: Equatable {
    var position: PanelPosition = .center
}

struct BehaviorConfig: Equatable {
    /// Idle time before auto-closing the palette; `nil` or non-positive = disabled.
    var idleTimeout: TimeInterval? = nil
    /// Max gap between two modifier taps when using a `doubletap+` leader.
    var doubleTapWindow: TimeInterval = 0.35
    /// Min gap between taps; shorter gaps are treated as key bounce.
    var doubleTapMinGap: TimeInterval = 0.08
    /// Ignore new double-taps for this long after a successful trigger.
    var doubleTapCooldown: TimeInterval = 0.5
}

struct Config: Equatable {
    let leader: Leader
    let bindings: [[String]: Action]
    let groupTitles: [[String]: String]
    let panel: PanelConfig
    let behavior: BehaviorConfig
    let launchAtLogin: Bool
    /// Resolved absolute path to the shell executable for `run` commands.
    let shellPath: String

    init(
        leader: Leader,
        bindings: [[String]: Action],
        groupTitles: [[String]: String],
        panel: PanelConfig = PanelConfig(),
        behavior: BehaviorConfig = BehaviorConfig(),
        launchAtLogin: Bool = false,
        shellPath: String = "/bin/sh"
    ) {
        self.leader = leader
        self.bindings = bindings
        self.groupTitles = groupTitles
        self.panel = panel
        self.behavior = behavior
        self.launchAtLogin = launchAtLogin
        self.shellPath = shellPath
    }
}
