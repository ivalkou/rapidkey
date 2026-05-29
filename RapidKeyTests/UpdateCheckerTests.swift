import XCTest
@testable import RapidKey

final class UpdateCheckerTests: XCTestCase {
    func testEqualVersionsAreNotNewer() {
        XCTAssertFalse(VersionComparison.isVersion("0.2.5", newerThan: "0.2.5"))
        XCTAssertFalse(VersionComparison.isVersion("v0.2.5", newerThan: "0.2.5"))
    }

    func testNewerPatchVersion() {
        XCTAssertTrue(VersionComparison.isVersion("0.2.6", newerThan: "0.2.5"))
        XCTAssertFalse(VersionComparison.isVersion("0.2.5", newerThan: "0.2.6"))
    }

    func testNewerMinorVersion() {
        XCTAssertTrue(VersionComparison.isVersion("0.3.0", newerThan: "0.2.5"))
        XCTAssertFalse(VersionComparison.isVersion("0.2.5", newerThan: "0.3.0"))
    }

    func testNewerMajorVersion() {
        XCTAssertTrue(VersionComparison.isVersion("1.0.0", newerThan: "0.9.9"))
    }

    func testDifferentLengthVersions() {
        XCTAssertTrue(VersionComparison.isVersion("0.2", newerThan: "0.1.9"))
        XCTAssertTrue(VersionComparison.isVersion("0.2.1", newerThan: "0.2"))
    }

    func testPrefixVIsIgnored() {
        XCTAssertTrue(VersionComparison.isVersion("v1.0.0", newerThan: "0.2.5"))
    }
}
