import XCTest
@testable import RapidKey

final class TerminalOutputSanitizerTests: XCTestCase {
    func testStripsANSIColorCodes() {
        let raw = "\u{001B}[31merror\u{001B}[0m"
        XCTAssertEqual(TerminalOutputSanitizer.strippingANSI(raw), "error")
    }

    func testEmptyStringUnchanged() {
        XCTAssertEqual(TerminalOutputSanitizer.strippingANSI(""), "")
    }

    func testPlainTextUnchanged() {
        let plain = "hello\nworld"
        XCTAssertEqual(TerminalOutputSanitizer.strippingANSI(plain), plain)
    }
}
