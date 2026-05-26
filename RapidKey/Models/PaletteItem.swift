import Foundation

enum PaletteItemKind: Equatable {
    case group(count: Int)
    case run
    case open
    case url
    case switchApp
}

enum PaletteAppIconRef: Equatable {
    case applicationName(String)
    case processID(pid_t)
}

struct PaletteItem: Identifiable, Equatable {
    let id: String
    let key: String
    let title: String
    let kind: PaletteItemKind
    let appIconRef: PaletteAppIconRef?

    init(key: String, title: String, kind: PaletteItemKind, appIconRef: PaletteAppIconRef? = nil) {
        self.id = key
        self.key = key
        self.title = title
        self.kind = kind
        self.appIconRef = appIconRef
    }
}
