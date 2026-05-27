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

    var onCancel: (() -> Void)?

    private var totalLength = 0
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
        session.totalLength = min(
            payload.stdout.count + payload.stderr.count + (payload.launchError?.count ?? 0),
            outputLimit
        )
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
        guard !cleaned.isEmpty, totalLength < Self.outputLimit else { return }
        let remaining = Self.outputLimit - totalLength
        let slice = cleaned.count > remaining ? String(cleaned.prefix(remaining)) : cleaned
        pending += slice
        totalLength += slice.count
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
            outputGeneration += 1
        }
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
        return joined.count > Self.outputLimit
            ? String(joined.prefix(Self.outputLimit)) + "\n…"
            : joined
    }
}
