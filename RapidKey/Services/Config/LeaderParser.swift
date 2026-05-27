import Carbon
import Foundation

enum LeaderParser {
    static func parseLeader(_ raw: String) throws -> Leader {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { throw HotkeyParseError.empty }

        if trimmed.hasPrefix("doubletap+") || trimmed.hasPrefix("2tap+") {
            let prefix = trimmed.hasPrefix("doubletap+") ? "doubletap+" : "2tap+"
            let modPart = String(trimmed.dropFirst(prefix.count))
            guard !modPart.isEmpty, !modPart.contains("+") else {
                throw HotkeyParseError.unknownLeader(raw)
            }
            switch modPart {
            case "ctrl", "control": return .doubleTapModifier(.ctrl)
            case "alt", "option": return .doubleTapModifier(.alt)
            case "cmd", "command": return .doubleTapModifier(.cmd)
            case "shift": return .doubleTapModifier(.shift)
            default: throw HotkeyParseError.unknownLeader(raw)
            }
        }

        return try parseChord(trimmed)
    }

    private static func parseChord(_ raw: String) throws -> Leader {
        let parts = raw
            .split(separator: "+", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        guard let last = parts.last else { throw HotkeyParseError.empty }
        guard parts.count >= 1 else { throw HotkeyParseError.empty }

        if parts.count == 1 {
            switch last {
            case "ctrl", "control", "alt", "option", "cmd", "command", "shift":
                throw HotkeyParseError.bareModifierNotAllowed
            default:
                break
            }
        }

        var mods: UInt32 = 0
        for p in parts.dropLast() {
            switch p {
            case "ctrl", "control": mods |= UInt32(controlKey)
            case "alt", "option": mods |= UInt32(optionKey)
            case "cmd", "command": mods |= UInt32(cmdKey)
            case "shift": mods |= UInt32(shiftKey)
            default: throw HotkeyParseError.unknownModifier(p)
            }
        }

        let keyCode = try keyCodeForToken(last)
        return .chord(keyCode: keyCode, modifiers: mods)
    }

    private static func keyCodeForToken(_ token: String) throws -> UInt32 {
        guard let vk = PhysicalUSKeyMap.keyCode(for: token) else {
            throw HotkeyParseError.unknownKey(token)
        }
        return vk
    }
}
