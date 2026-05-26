import SwiftUI

struct ConfirmRunView: View {
    let context: ConfirmRunContext

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(nsColor: .systemOrange))
                .padding(.top, 2)

            Text(context.message)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ConfirmRunFooterView: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .opacity(PaletteTheme.dividerOpacity(for: colorScheme) * 0.85)

            HStack {
                ServiceKeyChip(key: "y", label: "run", action: onConfirm)
                Spacer(minLength: 0)
                ServiceKeyChip(key: "n/esc", label: "cancel", action: onCancel)
            }
            .padding(.top, 10)
        }
    }
}
