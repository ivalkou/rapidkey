import SwiftUI

struct PaletteServiceFooter<Content: View>: View {
    @ViewBuilder let content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .opacity(PaletteTheme.dividerOpacity(for: colorScheme) * 0.85)

            HStack {
                content()
            }
            .padding(.top, 10)
        }
    }
}
