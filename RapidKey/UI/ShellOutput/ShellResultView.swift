import SwiftUI

struct ShellResultView: View {
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
        .panelChrome()
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
        PaletteServiceFooter {
            if session.canCancel {
                ServiceKeyChip(key: "ctrl+c", label: "stop", action: { session.requestCancel() })
                    .focusEffectDisabled()
            }
            Spacer()
            ServiceKeyChip(key: "esc", label: "close", action: onClose)
                .focusEffectDisabled()
        }
    }
}
