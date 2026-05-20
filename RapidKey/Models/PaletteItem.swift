import Foundation

enum PaletteItemKind: Equatable {
    case group(count: Int)
    case run
    case open
    case url
}

struct PaletteItem: Identifiable, Equatable {
    let id: String
    let key: String
    let title: String
    let kind: PaletteItemKind

    init(key: String, title: String, kind: PaletteItemKind) {
        self.id = key
        self.key = key
        self.title = title
        self.kind = kind
    }
}
