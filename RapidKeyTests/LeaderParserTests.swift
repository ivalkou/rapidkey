import XCTest
@testable import RapidKey

final class LeaderParserTests: XCTestCase {
    func testParseChordLeader() throws {
        let leader = try LeaderParser.parseLeader("alt+space")
        guard case .chord(let keyCode, let modifiers) = leader else {
            return XCTFail("Expected chord leader")
        }
        XCTAssertEqual(keyCode, 0x31)
        XCTAssertNotEqual(modifiers, 0)
    }

    func testParseDoubleTapLeader() throws {
        let leader = try LeaderParser.parseLeader("doubletap+ctrl")
        XCTAssertEqual(leader, .doubleTapModifier(.ctrl))
        XCTAssertTrue(leader.requiresInputMonitoring)
    }

    func testBareModifierRejected() {
        XCTAssertThrowsError(try LeaderParser.parseLeader("ctrl")) { error in
            XCTAssertEqual(error as? HotkeyParseError, .bareModifierNotAllowed)
        }
    }

    func testUnknownKeyRejected() {
        XCTAssertThrowsError(try LeaderParser.parseLeader("alt+notakey")) { error in
            guard let parseError = error as? HotkeyParseError,
                  case .unknownKey(let token) = parseError else {
                return XCTFail("Expected unknownKey")
            }
            XCTAssertEqual(token, "notakey")
        }
    }
}
