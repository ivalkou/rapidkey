import SwiftUI

struct PaletteFooterView: View {
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .opacity(PaletteTheme.dividerOpacity(for: colorScheme) * 0.85)

            HStack {
                Spacer(minLength: 0)
                ServiceKeyChip(key: "esc", label: "close", action: onClose)
            }
            .padding(.top, 10)
        }
    }
}
