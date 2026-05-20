import Carbon
import Foundation

enum LeaderModifier: String, Equatable {
    case ctrl
    case alt
    case cmd
    case shift
}

enum Leader: Equatable {
    case chord(keyCode: UInt32, modifiers: UInt32)
    case doubleTapModifier(LeaderModifier)

    /// Human-readable label for UI (e.g. `alt+space`, `double-tap ctrl`).
    var displayString: String {
        switch self {
        case .chord(let keyCode, let modifiers):
            var parts: [String] = []
            if modifiers & UInt32(controlKey) != 0 { parts.append("ctrl") }
            if modifiers & UInt32(optionKey) != 0 { parts.append("alt") }
            if modifiers & UInt32(cmdKey) != 0 { parts.append("cmd") }
            if modifiers & UInt32(shiftKey) != 0 { parts.append("shift") }
            let keyToken = PhysicalUSKeyMap.vkToToken[keyCode] ?? "?"
            parts.append(keyToken)
            return parts.joined(separator: "+")
        case .doubleTapModifier(let mod):
            return "double-tap \(mod.rawValue)"
        }
    }

    var requiresInputMonitoring: Bool {
        if case .doubleTapModifier = self { return true }
        return false
    }
}

enum HotkeyParseError: LocalizedError {
    case empty
    case unknownModifier(String)
    case unknownKey(String)
    case unknownLeader(String)
    case bareModifierNotAllowed

    var errorDescription: String? {
        switch self {
        case .empty: "Empty leader string"
        case .unknownModifier(let m): "Unknown modifier: \(m)"
        case .unknownKey(let k): "Unknown key: \(k)"
        case .unknownLeader(let s): "Unknown leader: \(s)"
        case .bareModifierNotAllowed: "Bare modifier is not a valid leader; use doubletap+modifier"
        }
    }
}
