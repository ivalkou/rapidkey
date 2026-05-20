import SwiftUI

struct PaletteHeaderView: View {
    let prefix: [String]
    let currentGroupTitle: String?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if prefix.isEmpty {
                Text("RapidKey")
                    .font(.headline)
                    .foregroundStyle(.primary)
            } else {
                HStack(spacing: 6) {
                    ForEach(Array(prefix.enumerated()), id: \.offset) { idx, token in
                        if idx > 0 {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        KeyChip(key: token, tint: PaletteTheme.groupAccent(for: colorScheme))
                    }
                }

                if let currentGroupTitle {
                    Text(currentGroupTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }
}
