import AppKit
import SwiftUI

struct PaletteErrorBanner: View {
    let message: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(nsColor: .systemRed))
            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: PaletteTheme.rowCornerRadius, style: .continuous)
                .fill(Color(nsColor: .systemRed).opacity(PaletteTheme.errorBannerFillOpacity(for: colorScheme)))
        }
    }
}
