import Foundation
import SwiftUI

struct ConfirmRunContext: Equatable {
    let message: String
    let action: Action
    let breadcrumbPrefix: [String]
}

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

    var body: some View {
        PaletteServiceFooter {
            ServiceKeyChip(key: "y", label: "run", action: onConfirm)
            Spacer(minLength: 0)
            ServiceKeyChip(key: "n/esc", label: "cancel", action: onCancel)
        }
    }
}
