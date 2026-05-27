import XCTest
@testable import RapidKey

final class ConfigLoaderTests: XCTestCase {
    func testParseLeaderDelegatesToLeaderParser() throws {
        let leader = try ConfigLoader.parseLeader("alt+space")
        guard case .chord(let keyCode, _) = leader else {
            return XCTFail("Expected chord")
        }
        XCTAssertEqual(keyCode, 0x31)
    }
}
