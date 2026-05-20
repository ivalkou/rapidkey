import Foundation

/// Physical key positions → config binding tokens (layout-independent).
enum PhysicalUSKeyMap {
    static let charToVK: [Character: UInt32] = [
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

    /// Token strings match `parseSequenceKey` / TOML binding keys (lowercase).
    static let vkToToken: [UInt32: String] = {
        var m: [UInt32: String] = [:]
        for (ch, vk) in charToVK {
            let t = String(ch).lowercased()
            if m[vk] == nil { m[vk] = t }
        }
        m[0x31] = "space"
        m[0x30] = "tab"
        m[0x24] = "return"
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

    /// Maps hardware `keyCode` to a binding token, ignoring current input source layout.
    static func bindingToken(keyCode: UInt16) -> String? {
        vkToToken[UInt32(keyCode)]
    }
}
