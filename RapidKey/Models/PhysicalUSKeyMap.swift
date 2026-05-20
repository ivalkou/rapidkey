import Foundation

/// Physical key positions → config binding tokens (layout-independent).
enum PhysicalUSKeyMap {
    private static let baseCharToVK: [Character: UInt32] = [
        "a": 0x00, "b": 0x0B, "c": 0x08, "d": 0x02, "e": 0x0E, "f": 0x03,
        "g": 0x05, "h": 0x04, "i": 0x22, "j": 0x26, "k": 0x28, "l": 0x25,
        "m": 0x2E, "n": 0x2D, "o": 0x1F, "p": 0x23, "q": 0x0C, "r": 0x0F,
        "s": 0x01, "t": 0x11, "u": 0x20, "v": 0x09, "w": 0x0D, "x": 0x07,
        "y": 0x10, "z": 0x06,
        "0": 0x1D, "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "5": 0x17,
        "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19,
        "=": 0x18, "-": 0x1B, "[": 0x21, "]": 0x1E, "'": 0x27, ";": 0x29,
        "\\": 0x2A, ",": 0x2B, "/": 0x2C, ".": 0x2F, "`": 0x32,
    ]

    /// US QWERTY: unshifted binding token → shifted token (same physical key).
    static let baseToShifted: [String: String] = [
        "1": "!", "2": "@", "3": "#", "4": "$", "5": "%",
        "6": "^", "7": "&", "8": "*", "9": "(", "0": ")",
        "-": "_", "=": "+", "[": "{", "]": "}", "\\": "|",
        ";": ":", "'": "\"", ",": "<", ".": ">", "/": "?", "`": "~",
    ]

    static let charToVK: [Character: UInt32] = {
        var m = baseCharToVK
        for (base, shifted) in baseToShifted {
            guard base.count == 1, let b = base.first, let vk = baseCharToVK[b],
                  shifted.count == 1, let s = shifted.first else { continue }
            m[s] = vk
        }
        for (ch, vk) in baseCharToVK where ch.isLetter {
            m[Character(String(ch).uppercased())] = vk
        }
        return m
    }()

    static let namedTokens: Set<String> = [
        "space", "tab", "return", "escape",
        "f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8", "f9", "f10", "f11", "f12",
    ]

    /// Token strings match `parseSequenceKey` / TOML binding keys (lowercase base keys).
    static let vkToToken: [UInt32: String] = {
        var m: [UInt32: String] = [:]
        for (ch, vk) in baseCharToVK {
            let t = String(ch).lowercased()
            if m[vk] == nil { m[vk] = t }
        }
        m[0x31] = "space"
        m[0x30] = "tab"
        m[0x24] = "return"
        m[0x33] = "backspace"
        m[0x35] = "escape"
        m[0x7A] = "f1"
        m[0x78] = "f2"
        m[0x63] = "f3"
        m[0x76] = "f4"
        m[0x60] = "f5"
        m[0x61] = "f6"
        m[0x62] = "f7"
        m[0x64] = "f8"
        m[0x65] = "f9"
        m[0x6D] = "f10"
        m[0x67] = "f11"
        m[0x6F] = "f12"
        return m
    }()

    /// Canonical binding token (aliases `esc` → `escape`, `enter` → `return`).
    static func normalizeBindingToken(_ token: String) -> String {
        let lower = token.count == 1 ? token : token.lowercased()
        switch lower {
        case "esc": return "escape"
        case "enter": return "return"
        default: return lower
        }
    }

    static func shiftedToken(for baseToken: String) -> String? {
        baseToShifted[baseToken]
    }

    static func isKnownToken(_ token: String) -> Bool {
        keyCode(for: token) != nil
    }

    /// US QWERTY virtual key code for a binding token, or nil if unknown.
    static func keyCode(for token: String) -> UInt32? {
        let normalized = normalizeBindingToken(token)
        if normalized.count == 1, let ch = normalized.first, let vk = charToVK[ch] {
            return vk
        }
        switch normalized {
        case "space": return 0x31
        case "tab": return 0x30
        case "return": return 0x24
        case "escape": return 0x35
        case "f1": return 0x7A
        case "f2": return 0x78
        case "f3": return 0x63
        case "f4": return 0x76
        case "f5": return 0x60
        case "f6": return 0x61
        case "f7": return 0x62
        case "f8": return 0x64
        case "f9": return 0x65
        case "f10": return 0x6D
        case "f11": return 0x67
        case "f12": return 0x6F
        default: return nil
        }
    }

    /// Maps hardware `keyCode` to a binding token, ignoring current input source layout.
    static func bindingToken(keyCode: UInt16) -> String? {
        vkToToken[UInt32(keyCode)]
    }
}
