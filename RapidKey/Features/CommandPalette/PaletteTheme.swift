import AppKit
import SwiftUI

enum PaletteTheme {
    /// Panel chrome: `0` = rectangle; a small value (e.g. 4) gives a subtle corner radius.
    static let panelCornerRadius: CGFloat = 8
    static let rowCornerRadius: CGFloat = 8
    static let keyChipCornerRadius: CGFloat = 6
    static let keyChipMinWidth: CGFloat = 28

    static let runAccent = Color(nsColor: .systemOrange)
    static let openAccent = Color(nsColor: .systemBlue)
    static let urlAccent = Color(nsColor: .systemPurple)

    /// Slightly denser material in light mode so content behind the panel does not wash out the UI.
    static func panelMaterial(for scheme: ColorScheme) -> Material {
        switch scheme {
        case .light: .regularMaterial
        case .dark: .regularMaterial
        @unknown default: .regularMaterial
        } 
    }

    /// Light: dark edge on bright blur; dark: soft highlight on dark blur.
    static func panelStrokeGradient(for scheme: ColorScheme) -> LinearGradient {
        switch scheme {
        case .light:
            LinearGradient(
                colors: [
                    Color.black.opacity(0.11),
                    Color.black.opacity(0.045),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        default:
            LinearGradient(
                colors: [
                    Color.white.opacity(0.22),
                    Color.white.opacity(0.04),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    static func dividerOpacity(for scheme: ColorScheme) -> Double {
        scheme == .light ? 0.55 : 0.4
    }

    static func keyChipNeutralFill(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color.black.opacity(0.07) : Color.primary.opacity(0.10)
    }

    static func keyChipBorder(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color.black.opacity(0.14) : Color.primary.opacity(0.18)
    }

    static func rowHoverFill(isHovered: Bool, for scheme: ColorScheme) -> Color {
        guard isHovered else { return .clear }
        return scheme == .light ? Color.black.opacity(0.07) : Color.primary.opacity(0.06)
    }

    static func errorBannerFillOpacity(for scheme: ColorScheme) -> Double {
        scheme == .light ? 0.18 : 0.12
    }

    /// `systemTeal` on light blur reads as weak pastel; blend toward label for readable titles and icons.
    static func groupAccent(for scheme: ColorScheme) -> Color {
        guard scheme == .light else {
            return Color(nsColor: .systemTeal)
        }
        let base = NSColor.systemTeal
        let mixed = base.blended(withFraction: 0.42, of: .labelColor) ?? base
        return Color(nsColor: mixed)
    }
}
