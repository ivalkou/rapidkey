import SwiftUI

struct KeyChip: View {
    let key: String
    var tint: Color?

    @Environment(\.colorScheme) private var colorScheme

    init(key: String, tint: Color? = nil) {
        self.key = key
        self.tint = tint
    }

    var body: some View {
        Text(key)
            .font(.system(.subheadline, design: .monospaced, weight: .semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(tint ?? Color.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(minWidth: PaletteTheme.keyChipMinWidth)
            .background(chipBackground)
    }

    private var chipBackground: some View {
        let fill: Color = {
            if let tint {
                tint.opacity(colorScheme == .light ? 0.22 : 0.18)
            } else {
                PaletteTheme.keyChipNeutralFill(for: colorScheme)
            }
        }()

        return RoundedRectangle(cornerRadius: PaletteTheme.keyChipCornerRadius, style: .continuous)
            .fill(fill)
            .overlay {
                RoundedRectangle(cornerRadius: PaletteTheme.keyChipCornerRadius, style: .continuous)
                    .strokeBorder(PaletteTheme.keyChipBorder(for: colorScheme), lineWidth: 1)
            }
    }
}
