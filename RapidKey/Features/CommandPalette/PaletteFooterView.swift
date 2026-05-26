import SwiftUI

struct PaletteFooterView: View {
    let showSpace: Bool
    let onSpace: () -> Void
    let showBack: Bool
    let onBack: () -> Void
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .opacity(PaletteTheme.dividerOpacity(for: colorScheme) * 0.85)

            HStack {
                if showSpace {
                    ServiceKeyChip(key: "space", label: "running apps", action: onSpace)
                } else if showBack {
                    ServiceKeyChip(key: "backspace", label: "back", action: onBack)
                }
                Spacer(minLength: 0)
                ServiceKeyChip(key: "esc", label: "close", action: onClose)
            }
            .animation(nil, value: showSpace)
            .animation(nil, value: showBack)
            .padding(.top, 10)
        }
    }
}
