import XCTest
@testable import RapidKey

@MainActor
final class ShellResultSessionTests: XCTestCase {
    func testShortOutputIsKeptWhole() {
        let session = ShellResultSession(command: "echo hi")
        session.appendStdout("hello\nworld\n")
        session.flushPendingOutput()

        XCTAssertEqual(session.stdout, "hello\nworld\n")
        XCTAssertFalse(session.didTruncateHead)
        XCTAssertEqual(session.composedOutput, "hello\nworld")
    }

    func testOverflowingOutputKeepsTail() {
        let session = ShellResultSession(command: "build")
        let head = String(repeating: "header line\n", count: 2_000)
        session.appendStdout(head)
        session.appendStdout("error: something broke\n")
        session.flushPendingOutput()

        XCTAssertTrue(session.didTruncateHead)
        XCTAssertLessThanOrEqual(session.stdout.count, ShellResultSession.outputLimit)
        XCTAssertTrue(session.stdout.hasSuffix("error: something broke\n"))
    }

    func testTruncationCutsAtLineBoundary() {
        let session = ShellResultSession(command: "build")
        session.appendStdout(String(repeating: "0123456789\n", count: 2_000))
        session.flushPendingOutput()

        XCTAssertTrue(session.didTruncateHead)
        XCTAssertTrue(session.stdout.hasPrefix("0123456789\n"))
    }

    func testTruncatedOutputIsMarkedWithEllipsis() {
        let session = ShellResultSession(command: "build")
        session.appendStdout(String(repeating: "line\n", count: 5_000))
        session.flushPendingOutput()

        XCTAssertTrue(session.composedOutput.hasPrefix("…\n"))
    }

    func testFinishedPayloadKeepsTail() {
        let payload = ShellResultPayload(
            style: .failure,
            command: "build",
            exitCode: 65,
            launchError: nil,
            stdout: String(repeating: "header line\n", count: 2_000) + "error: something broke\n",
            stderr: ""
        )
        let session = ShellResultSession.finished(from: payload)

        XCTAssertTrue(session.didTruncateHead)
        XCTAssertTrue(session.stdout.hasSuffix("error: something broke\n"))
    }
}
