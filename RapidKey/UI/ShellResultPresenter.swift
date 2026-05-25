import AppKit
import Combine
import SwiftUI

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

enum ShellResultPresenter {
    static func present(_ payload: ShellResultPayload, panel: PanelConfig) {
        Task { @MainActor in
            ShellResultPanelController.shared.show(payload: payload, panel: panel)
        }
    }

    static func presentStreaming(command: String, panel: PanelConfig) -> ShellResultSession {
        let session = ShellResultSession(command: command)
        ShellResultPanelController.shared.show(session: session, panel: panel)
        return session
    }
}

@MainActor
final class ShellResultPanelController: NSObject, NSWindowDelegate {
    static let shared = ShellResultPanelController()

    private var panel: ShellResultPanel?
    private var keyMonitor: Any?
    private var session: ShellResultSession?
    private var panelConfig = PanelConfig()

    func show(payload: ShellResultPayload, panel panelConfig: PanelConfig) {
        show(session: ShellResultSession.finished(from: payload), panel: panelConfig)
    }

    func show(session: ShellResultSession, panel panelConfig: PanelConfig) {
        dismissPanel(restoreFocus: false)

        self.session = session
        self.panelConfig = panelConfig
        let view = ShellResultView(session: session) { [weak self] in
            self?.hide()
        }
        let hosting = NSHostingView(rootView: view)
        if #available(macOS 13.0, *) {
            hosting.sizingOptions = [.minSize, .preferredContentSize]
        }

        let p = ShellResultPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 440),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .statusBar
        p.hidesOnDeactivate = false
        p.isMovableByWindowBackground = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.contentView = hosting
        p.delegate = self

        panel = p
        PanelPositioning.position(p, using: panelConfig)
        PreviousAppFocus.capture()
        p.orderFrontRegardless()
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let panel = self.panel, event.window === panel else { return event }
            if event.keyCode == 0x35 {
                self.hide()
                return nil
            }
            if event.modifierFlags.contains(.control),
               event.keyCode == 0x08,
               self.session?.canCancel == true {
                self.session?.requestCancel()
                return nil
            }
            return event
        }

        DispatchQueue.main.async { [weak self] in
            guard let self, let p = self.panel else { return }
            PanelPositioning.position(p, using: self.panelConfig)
        }
    }

    func hide() {
        dismissPanel(restoreFocus: true)
    }

    private func dismissPanel(restoreFocus: Bool) {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        panel?.orderOut(nil)
        panel = nil
        session = nil
        if restoreFocus {
            PreviousAppFocus.restoreIfRapidKeyStillFrontmost()
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        guard session?.isRunning != true else { return }
        hide()
    }
}

final class ShellResultPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct ShellResultView: View {
    private static let outputLogHeight: CGFloat = 280
    private static let commandBlockMaxHeight: CGFloat = 96

    @ObservedObject var session: ShellResultSession
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            commandBlock
            outputBlock
            footer
        }
        .padding(20)
        .background { panelFill }
        .overlay { panelStroke }
        .clipShape(RoundedRectangle(cornerRadius: PaletteTheme.panelCornerRadius, style: .continuous))
        .frame(minWidth: 380, idealWidth: 460, maxWidth: 640)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var isFailure: Bool { session.style == .failure && !session.wasCancelled }

    private var statusColor: Color {
        if session.isRunning {
            return Color(nsColor: .secondaryLabelColor)
        }
        if session.wasCancelled {
            return Color(nsColor: .systemOrange)
        }
        return Color(nsColor: isFailure ? .systemRed : .systemGreen)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Group {
                if session.isRunning {
                    ProgressView()
                        .controlSize(.small)
                } else if session.wasCancelled {
                    Image(systemName: "stop.circle.fill")
                } else {
                    Image(systemName: isFailure ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                }
            }
            .foregroundStyle(statusColor)
            Text(headerTitle)
                .font(.headline)
            Spacer(minLength: 8)
            statusBadge
        }
    }

    private var headerTitle: String {
        if session.isRunning { return "Running…" }
        if session.wasCancelled { return "Cancelled" }
        return isFailure ? "Command failed" : "Command output"
    }

    @ViewBuilder
    private var statusBadge: some View {
        if session.launchError?.isEmpty == false {
            badge(text: "error")
        } else if let code = session.exitCode, !session.isRunning {
            badge(text: "exit \(code)")
        }
    }

    private func badge(text: String) -> some View {
        Text(text)
            .font(.system(.footnote, design: .monospaced, weight: .semibold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(statusColor.opacity(0.16)))
    }

    private var commandBlock: some View {
        ScrollView {
            Text(session.command)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .scrollIndicators(.hidden)
        .frame(maxHeight: Self.commandBlockMaxHeight)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: PaletteTheme.rowCornerRadius, style: .continuous)
                .fill(PaletteTheme.keyChipNeutralFill(for: colorScheme))
        }
    }

    @ViewBuilder
    private var outputBlock: some View {
        let body = session.composedOutput
        Group {
            if body.isEmpty {
                Text(session.isRunning ? "Waiting for output…" : "(no output)")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(12)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(body)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                        Color.clear
                            .frame(height: 1)
                            .id("logBottom")
                    }
                    .onAppear { scrollToBottom(proxy) }
                    .onChange(of: session.outputGeneration) { _, _ in scrollToBottom(proxy) }
                }
            }
        }
        .frame(height: Self.outputLogHeight)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: PaletteTheme.rowCornerRadius, style: .continuous)
                .fill(PaletteTheme.keyChipNeutralFill(for: colorScheme))
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        proxy.scrollTo("logBottom", anchor: .bottom)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().opacity(PaletteTheme.dividerOpacity(for: colorScheme) * 0.85)
            HStack {
                if session.canCancel {
                    ServiceKeyChip(key: "ctrl+c", label: "stop", action: { session.requestCancel() })
                        .focusEffectDisabled()
                }
                Spacer()
                ServiceKeyChip(key: "esc", label: "close", action: onClose)
                    .focusEffectDisabled()
            }
            .padding(.top, 10)
        }
    }

    @ViewBuilder
    private var panelFill: some View {
        RoundedRectangle(cornerRadius: PaletteTheme.panelCornerRadius, style: .continuous)
            .fill(PaletteTheme.panelMaterial(for: colorScheme))
    }

    @ViewBuilder
    private var panelStroke: some View {
        RoundedRectangle(cornerRadius: PaletteTheme.panelCornerRadius, style: .continuous)
            .stroke(PaletteTheme.panelStrokeGradient(for: colorScheme), lineWidth: 1)
    }
}
