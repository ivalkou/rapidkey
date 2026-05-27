import SwiftUI

struct CommandPaletteView: View {
    @ObservedObject var state: CommandPaletteState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        paletteChrome
            .background(KeyCatcher { key in
                _ = state.handle(key)
            })
    }

    private var paletteChrome: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let message = state.errorMessage {
                PaletteErrorBanner(message: message)
                    .padding(.bottom, 10)
            }

            PaletteHeaderView(
                prefix: state.prefix,
                currentGroupTitle: state.currentGroupTitle
            )
            .animation(nil, value: state.prefix)

            Divider()
                .opacity(PaletteTheme.dividerOpacity(for: colorScheme))
                .padding(.top, 10)
                .padding(.bottom, 12)

            if let confirm = state.confirmContext {
                ConfirmRunView(context: confirm)
                    .padding(.bottom, 12)
            } else if state.items.isEmpty {
                Text(state.emptyMessage)
                    .foregroundStyle(.tertiary)
            } else {
                PaletteBindingsList(items: state.items) { key in
                    _ = state.handle(key)
                }
                .animation(nil, value: state.items)
            }

            if state.isConfirmingRun {
                ConfirmRunFooterView(
                    onConfirm: { _ = state.handle("y") },
                    onCancel: { _ = state.handle("n") }
                )
            } else {
                PaletteFooterView(
                    showSpace: state.isAtRoot,
                    onSpace: { _ = state.handle("space") },
                    showBack: !state.isAtRoot,
                    onBack: { _ = state.handle("backspace") },
                    onClose: { _ = state.handle("escape") }
                )
            }
        }
        .padding(20)
        .animation(.easeOut(duration: 0.15), value: state.errorMessage)
        .panelChrome()
        .frame(minWidth: 360, maxWidth: paletteMaxWidth)
        .fixedSize(horizontal: true, vertical: true)
    }

    private var paletteMaxWidth: CGFloat {
        let screenWidth = PanelPositioning.screenUnderMouseOrMain()?.visibleFrame.width ?? 800
        return max(360, screenWidth - 32)
    }
}
