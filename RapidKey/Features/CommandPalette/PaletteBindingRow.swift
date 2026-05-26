import SwiftUI

struct PaletteBindingRow: View {
    let item: PaletteItem
    let onSelectKey: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            KeyChip(key: item.key)

            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Image(systemName: iconName)
                .font(.caption)
                .foregroundStyle(accentColor)
                .frame(width: 14, alignment: .center)

            Text(item.title.isEmpty ? " " : item.title)
                .font(.body)
                .fontWeight(titleWeight)
                .foregroundStyle(titleColor)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            if case let .group(count) = item.kind, count > 0 {
                Text("+\(count)")
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .foregroundStyle(PaletteTheme.groupAccent(for: colorScheme))
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(PaletteTheme.groupAccent(for: colorScheme).opacity(colorScheme == .light ? 0.20 : 0.18))
                    )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: PaletteTheme.rowCornerRadius, style: .continuous)
                .fill(PaletteTheme.rowHoverFill(isHovered: isHovered, for: colorScheme))
        }
        .contentShape(RoundedRectangle(cornerRadius: PaletteTheme.rowCornerRadius, style: .continuous))
        .onHover { isHovered = $0 }
        .fixedSize(horizontal: true, vertical: false)
        .onTapGesture {
            onSelectKey(item.key)
        }
    }

    private var iconName: String {
        switch item.kind {
        case .group: return "folder.fill"
        case .run: return "terminal.fill"
        case .open: return "app.fill"
        case .url: return "link"
        case .switchApp: return "macwindow.on.rectangle"
        }
    }

    private var accentColor: Color {
        switch item.kind {
        case .group: return PaletteTheme.groupAccent(for: colorScheme)
        case .run: return PaletteTheme.runAccent
        case .open: return PaletteTheme.openAccent
        case .url: return PaletteTheme.urlAccent
        case .switchApp: return PaletteTheme.openAccent
        }
    }

    private var titleWeight: Font.Weight {
        switch item.kind {
        case .group: return .semibold
        case .run, .open, .url, .switchApp: return .regular
        }
    }

    private var titleColor: Color {
        switch item.kind {
        case .group: return PaletteTheme.groupAccent(for: colorScheme)
        case .run, .open, .url, .switchApp: return Color.primary
        }
    }
}
