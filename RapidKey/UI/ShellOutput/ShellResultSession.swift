import Combine
import Foundation

struct ShellResultPayload {
    enum Style {
        case output
        case failure
    }

    let style: Style
    let command: String
    let exitCode: Int32?
    let launchError: String?
    let stdout: String
    let stderr: String
}

@MainActor
final class ShellResultSession: ObservableObject {
    static let outputLimit = 16_000

    let command: String
    @Published var stdout = ""
    @Published var stderr = ""
    @Published var isRunning = true
    @Published private(set) var wasCancelled = false
    @Published var exitCode: Int32?
    @Published var launchError: String?
    @Published var style: ShellResultPayload.Style = .output

    @Published private(set) var didTruncateHead = false

    var onCancel: (() -> Void)?

    private var pendingStdout = ""
    private var pendingStderr = ""
    private var coalesceTask: Task<Void, Never>?
    @Published private(set) var outputGeneration = 0

    var canCancel: Bool { isRunning && onCancel != nil }

    init(command: String, running: Bool = true) {
        self.command = command
        self.isRunning = running
    }

    static func finished(from payload: ShellResultPayload) -> ShellResultSession {
        let session = ShellResultSession(command: payload.command, running: false)
        session.stdout = TerminalOutputSanitizer.strippingANSI(payload.stdout)
        session.stderr = TerminalOutputSanitizer.strippingANSI(payload.stderr)
        session.exitCode = payload.exitCode
        session.launchError = payload.launchError
        session.style = payload.style
        session.trimToLimit()
        return session
    }

    func appendStdout(_ chunk: String) {
        enqueue(chunk, into: &pendingStdout)
    }

    func appendStderr(_ chunk: String) {
        enqueue(chunk, into: &pendingStderr)
    }

    func flushPendingOutput() {
        coalesceTask?.cancel()
        coalesceTask = nil
        flushPending()
    }

    private func enqueue(_ chunk: String, into pending: inout String) {
        let cleaned = TerminalOutputSanitizer.strippingANSI(chunk)
        guard !cleaned.isEmpty else { return }

        pending += cleaned
        scheduleCoalescedFlush()
    }

    private func scheduleCoalescedFlush() {
        guard coalesceTask == nil else { return }
        coalesceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(32))
            guard let self else { return }
            self.coalesceTask = nil
            self.flushPending()
        }
    }

    private func flushPending() {
        var changed = false
        if !pendingStdout.isEmpty {
            stdout += pendingStdout
            pendingStdout = ""
            changed = true
        }
        if !pendingStderr.isEmpty {
            stderr += pendingStderr
            pendingStderr = ""
            changed = true
        }
        if changed {
            trimToLimit()
            outputGeneration += 1
        }
    }

    /// Build tools print failures at the end, while the first kilobytes are just a header,
    /// so an overflowing log has to lose its head, not its tail.
    private func trimToLimit() {
        var overflow = stdout.count + stderr.count - Self.outputLimit
        guard overflow > 0 else { return }

        if !stdout.isEmpty {
            let cut = min(overflow, stdout.count)
            stdout = Self.droppingLeadingPartialLine(from: stdout, by: cut)
            overflow -= cut
        }
        if overflow > 0, !stderr.isEmpty {
            stderr = Self.droppingLeadingPartialLine(from: stderr, by: min(overflow, stderr.count))
        }

        didTruncateHead = true
    }

    private static func droppingLeadingPartialLine(from text: String, by count: Int) -> String {
        let remainder = String(text.dropFirst(count))
        guard let lineBreak = remainder.firstIndex(of: "\n") else { return remainder }

        return String(remainder[remainder.index(after: lineBreak)...])
    }

    func requestCancel() {
        guard isRunning, !wasCancelled else { return }
        wasCancelled = true
        onCancel?()
    }

    func finish(exitCode: Int32?, launchError: String?, style: ShellResultPayload.Style) {
        flushPendingOutput()
        if wasCancelled {
            applyCancellationNotice()
        }
        self.exitCode = exitCode
        self.launchError = launchError
        self.style = style
        isRunning = false
        onCancel = nil
    }

    private func applyCancellationNotice() {
        stdout = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        stderr = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let notice = "Command interrupted."
        if stdout.isEmpty && stderr.isEmpty {
            stderr = notice
        } else if stderr.isEmpty {
            stdout += "\n\n" + notice
        } else {
            stderr += "\n\n" + notice
        }
        outputGeneration += 1
    }

    var composedOutput: String {
        let launch = (launchError ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var parts: [String] = []
        if !launch.isEmpty { parts.append(launch) }
        let out = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let err = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !out.isEmpty { parts.append(out) }
        if !err.isEmpty {
            parts.append(out.isEmpty ? err : "--- stderr ---\n\(err)")
        }
        let joined = parts.joined(separator: "\n\n")
        return didTruncateHead ? "…\n" + joined : joined
    }
}
