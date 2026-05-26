import Foundation

struct Action: Equatable {
    enum Kind: Equatable {
        case run(String, showOutput: Bool, workDir: String?, confirmMessage: String?)
        case open(String)
        case url(URL)
    }

    let title: String
    let kind: Kind
}
