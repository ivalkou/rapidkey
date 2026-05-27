import SwiftUI

struct PanelChromeModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background { panelFill }
            .overlay { panelStroke }
            .clipPanelChrome()
    }

    @ViewBuilder
    private var panelFill: some View {
        let material = PaletteTheme.panelMaterial(for: colorScheme)
        if PaletteTheme.panelCornerRadius <= 0 {
            Rectangle().fill(material)
        } else {
            RoundedRectangle(cornerRadius: PaletteTheme.panelCornerRadius, style: .continuous)
                .fill(material)
        }
    }

    @ViewBuilder
    private var panelStroke: some View {
        let stroke = PaletteTheme.panelStrokeGradient(for: colorScheme)
        if PaletteTheme.panelCornerRadius <= 0 {
            Rectangle().stroke(stroke, lineWidth: 1)
        } else {
            RoundedRectangle(cornerRadius: PaletteTheme.panelCornerRadius, style: .continuous)
                .stroke(stroke, lineWidth: 1)
        }
    }
}

extension View {
    func panelChrome() -> some View {
        modifier(PanelChromeModifier())
    }

    @ViewBuilder
    func clipPanelChrome() -> some View {
        if PaletteTheme.panelCornerRadius <= 0 {
            clipShape(Rectangle())
        } else {
            clipShape(
                RoundedRectangle(cornerRadius: PaletteTheme.panelCornerRadius, style: .continuous)
            )
        }
    }
}
