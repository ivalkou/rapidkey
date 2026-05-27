import XCTest
@testable import RapidKey

final class PhysicalUSKeyMapTests: XCTestCase {
    func testNormalizeBindingTokenAliases() {
        XCTAssertEqual(PhysicalUSKeyMap.normalizeBindingToken("esc"), "escape")
        XCTAssertEqual(PhysicalUSKeyMap.normalizeBindingToken("enter"), "return")
        XCTAssertEqual(PhysicalUSKeyMap.normalizeBindingToken("SPACE"), "space")
    }

    func testKeyCodeForLettersAndDigits() {
        XCTAssertEqual(PhysicalUSKeyMap.keyCode(for: "a"), 0x00)
        XCTAssertEqual(PhysicalUSKeyMap.keyCode(for: "1"), 0x12)
        XCTAssertEqual(PhysicalUSKeyMap.keyCode(for: "space"), 0x31)
        XCTAssertEqual(PhysicalUSKeyMap.keyCode(for: "f12"), 0x6F)
    }

    func testShiftedTokenPairsShareKeyCode() {
        XCTAssertEqual(PhysicalUSKeyMap.shiftedToken(for: "1"), "!")
        XCTAssertEqual(PhysicalUSKeyMap.keyCode(for: "1"), PhysicalUSKeyMap.keyCode(for: "!"))
    }

    func testBindingTokenRoundTrip() {
        XCTAssertEqual(PhysicalUSKeyMap.bindingToken(keyCode: 0x00), "a")
        XCTAssertEqual(PhysicalUSKeyMap.bindingToken(keyCode: 0x31), "space")
    }

    func testUnknownToken() {
        XCTAssertNil(PhysicalUSKeyMap.keyCode(for: "not-a-key"))
        XCTAssertFalse(PhysicalUSKeyMap.isKnownToken("not-a-key"))
    }
}
