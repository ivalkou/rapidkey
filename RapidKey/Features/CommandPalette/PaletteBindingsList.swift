import SwiftUI

/// Max rows before the binding list scrolls; keeps the panel from growing past the screen.
private enum PaletteBindingsListLayout {
    static let singleColumnMaxItemCount = 8
    static let maxVisibleRowsBeforeScroll = 12
    static let scrollListMaxHeight: CGFloat = 360
}

struct PaletteBindingsList: View {
    let items: [PaletteItem]
    let onSelectKey: (String) -> Void

    var body: some View {
        Group {
            if items.count <= PaletteBindingsListLayout.maxVisibleRowsBeforeScroll {
                listContent
            } else {
                ScrollView {
                    listContent
                }
                .frame(maxHeight: PaletteBindingsListLayout.scrollListMaxHeight)
            }
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if items.count <= PaletteBindingsListLayout.singleColumnMaxItemCount {
            bindingsColumn(items)
        } else {
            let split = splitIntoTwoColumns(items)
            HStack(alignment: .top, spacing: 20) {
                bindingsColumn(split.left)
                bindingsColumn(split.right)
            }
            .fixedSize(horizontal: true, vertical: true)
        }
    }

    private func bindingsColumn(_ columnItems: [PaletteItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(columnItems) { item in
                PaletteBindingRow(item: item, onSelectKey: onSelectKey)
            }
        }
        .fixedSize(horizontal: true, vertical: true)
    }

    private func splitIntoTwoColumns(_ items: [PaletteItem]) -> (left: [PaletteItem], right: [PaletteItem]) {
        let mid = (items.count + 1) / 2
        return (Array(items.prefix(mid)), Array(items.dropFirst(mid)))
    }
}
