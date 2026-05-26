import Foundation

struct ConfirmRunContext: Equatable {
    let message: String
    let action: Action
    let breadcrumbPrefix: [String]
}
