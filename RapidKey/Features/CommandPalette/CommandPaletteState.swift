import AppKit
import Combine
import Foundation

@MainActor
final class CommandPaletteState: ObservableObject {
    @Published var prefix: [String] = []
    @Published var items: [PaletteItem] = []
    @Published var errorMessage: String?

    /// When set, called after idle timeout (e.g. hide panel).
    var onAutoClose: (() -> Void)?
    /// When false, idle timer is not scheduled (panel closed or not key).
    var isPanelKeyAndVisible: (() -> Bool)?

    private let configStore: ConfigStore
    private var cancellables = Set<AnyCancellable>()
    private var idleTask: DispatchWorkItem?

    init(configStore: ConfigStore) {
        self.configStore = configStore

        configStore.$config
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.reset(scheduleIdleTimeout: true)
            }
            .store(in: &cancellables)

        configStore.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.errorMessage = $0
            }
            .store(in: &cancellables)

        refreshItems()
    }

    func cancelIdleTimer() {
        idleTask?.cancel()
        idleTask = nil
    }

    private func armIdleTimer() {
        idleTask?.cancel()
        guard isPanelKeyAndVisible?() == true else { return }
        guard let t = configStore.config.behavior.idleTimeout, t > 0 else { return }
        let work = DispatchWorkItem { [weak self] in
            self?.onAutoClose?()
            self?.reset(scheduleIdleTimeout: false)
        }
        idleTask = work
        DispatchQueue.main.asyncAfter(deadline: .now() + t, execute: work)
    }

    /// Call after the panel is visible and key (e.g. end of `show()`).
    func scheduleIdleTimeoutIfNeeded() {
        armIdleTimer()
    }

    func reset(scheduleIdleTimeout: Bool = true) {
        prefix = []
        refreshItems()
        if scheduleIdleTimeout {
            armIdleTimer()
        }
    }

    /// Title for the current prefix path (from `groupTitles`), if any.
    var currentGroupTitle: String? {
        let s = configStore.config.groupTitles[prefix] ?? ""
        return s.isEmpty ? nil : s
    }

    private func refreshItems() {
        let cfg = configStore.config
        items = Self.buildItems(prefix: prefix, config: cfg)
    }

    private static func bindingKeys(extending prefix: [String], bindings: [[String]: Action]) -> [[String]] {
        bindings.keys.filter { key in
            key.count > prefix.count && Array(key.prefix(prefix.count)) == prefix
        }
    }

    private static func lexPath(_ a: [String], _ b: [String]) -> Bool {
        let n = min(a.count, b.count)
        for i in 0..<n {
            if a[i] == b[i] { continue }
            let al = a[i].lowercased()
            let bl = b[i].lowercased()
            if al != bl { return al < bl }
            // Same letters ignoring case: lowercase before uppercase (e.g. t before T).
            let aLower = a[i] == al
            let bLower = b[i] == bl
            if aLower != bLower { return aLower }
            return a[i] < b[i]
        }
        return a.count < b.count
    }

    private static func subtreeBindingCount(prefix path: [String], bindings: [[String]: Action]) -> Int {
        bindings.keys.filter { key in
            key.count > path.count && Array(key.prefix(path.count)) == path
        }.count
    }

    private static func buildItems(prefix: [String], config: Config) -> [PaletteItem] {
        let keys = bindingKeys(extending: prefix, bindings: config.bindings)
        var seen = Set<String>()
        var rows: [PaletteItem] = []
        for key in keys.sorted(by: lexPath) {
            guard key.count > prefix.count else { continue }
            let token = key[prefix.count]
            guard seen.insert(token).inserted else { continue }

            let nextPath = prefix + [token]
            let item: PaletteItem
            if let action = config.bindings[nextPath] {
                let kind: PaletteItemKind
                switch action.kind {
                case .run: kind = .run
                case .open: kind = .open
                case .url: kind = .url
                }
                item = PaletteItem(key: token, title: action.title, kind: kind)
            } else {
                let title = config.groupTitles[nextPath] ?? ""
                let subtreeCount = subtreeBindingCount(prefix: nextPath, bindings: config.bindings)
                item = PaletteItem(key: token, title: title, kind: .group(count: subtreeCount))
            }
            rows.append(item)
        }
        return rows
    }

    func handle(_ key: String) -> Bool {
        if key == "escape" {
            cancelIdleTimer()
            NSApp.keyWindow?.orderOut(nil)
            reset(scheduleIdleTimeout: false)
            return true
        }

        let cfg = configStore.config
        let next = prefix + [key]

        if let action = cfg.bindings[next] {
            ActionRunner.run(action, shellPath: cfg.shellPath, panel: cfg.panel)
            cancelIdleTimer()
            NSApp.keyWindow?.orderOut(nil)
            reset(scheduleIdleTimeout: false)
            return true
        }

        let hasDescendant = cfg.bindings.keys.contains { path in
            path.count > next.count && Array(path.prefix(next.count)) == next
        }
        if hasDescendant {
            prefix = next
            refreshItems()
            armIdleTimer()
            return true
        }

        return false
    }
}
