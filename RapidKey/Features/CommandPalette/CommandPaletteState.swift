import AppKit
import Combine
import Foundation

enum PaletteBranch: Equatable {
    case config(prefix: [String])
    case runningApps(snapshot: [RunningAppEntry])
    case confirmRun(ConfirmRunContext)
}

@MainActor
final class CommandPaletteState: ObservableObject {
    @Published var branch: PaletteBranch = .config(prefix: [])
    @Published var items: [PaletteItem] = []
    @Published var errorMessage: String?

    /// When set, called after idle timeout (e.g. hide panel).
    var onAutoClose: (() -> Void)?
    /// When set, called to dismiss the panel.
    /// - Parameters:
    ///   - restoreFocus: activate the app that was frontmost before the palette opened.
    ///   - discardSavedFocus: drop the saved app without restoring (e.g. hand off to another app).
    var onDismiss: ((_ restoreFocus: Bool, _ discardSavedFocus: Bool) -> Void)?
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

    var isAtRoot: Bool {
        if case .config(let prefix) = branch { return prefix.isEmpty }
        return false
    }

    /// Breadcrumb tokens for the palette header.
    var prefix: [String] {
        switch branch {
        case .config(let prefix):
            return prefix
        case .runningApps:
            return ["space"]
        case .confirmRun(let context):
            return context.breadcrumbPrefix
        }
    }

    var isConfirmingRun: Bool {
        if case .confirmRun = branch { return true }
        return false
    }

    var confirmContext: ConfirmRunContext? {
        if case .confirmRun(let context) = branch { return context }
        return nil
    }

    var emptyMessage: String {
        switch branch {
        case .config:
            return "No bindings in config"
        case .runningApps:
            return "No running apps"
        case .confirmRun:
            return ""
        }
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
        branch = .config(prefix: [])
        refreshItems()
        if scheduleIdleTimeout {
            armIdleTimer()
        }
    }

    /// Title for the current prefix path (from `groupTitles`), if any.
    var currentGroupTitle: String? {
        switch branch {
        case .config(let prefix):
            let s = configStore.config.groupTitles[prefix] ?? ""
            return s.isEmpty ? nil : s
        case .runningApps:
            return "Running Apps"
        case .confirmRun:
            return "Confirm"
        }
    }

    private static func breadcrumbPrefix(for branch: PaletteBranch) -> [String] {
        switch branch {
        case .config(let prefix):
            return prefix
        case .runningApps:
            return ["space"]
        case .confirmRun(let context):
            return context.breadcrumbPrefix
        }
    }

    private func dismissPalette(restoreFocus: Bool = true) {
        cancelIdleTimer()
        onDismiss?(restoreFocus, false)
        reset(scheduleIdleTimeout: false)
    }

    private func refreshItems() {
        let cfg = configStore.config
        switch branch {
        case .config(let prefix):
            items = Self.buildConfigItems(prefix: prefix, config: cfg)
        case .runningApps(let snapshot):
            let showIcons = cfg.panel.showAppIcons
            items = snapshot.map { entry in
                PaletteItem(
                    key: entry.key,
                    title: entry.title,
                    kind: .switchApp,
                    appIconRef: showIcons ? .processID(entry.pid) : nil
                )
            }
        case .confirmRun:
            items = []
        }
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

    private static func buildConfigItems(prefix: [String], config: Config) -> [PaletteItem] {
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
                var appIconRef: PaletteAppIconRef?
                switch action.kind {
                case .run: kind = .run
                case .open(let name):
                    kind = .open
                    if config.panel.showAppIcons {
                        appIconRef = .applicationName(name)
                    }
                case .url: kind = .url
                }
                item = PaletteItem(key: token, title: action.title, kind: kind, appIconRef: appIconRef)
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
        let key = PhysicalUSKeyMap.normalizeBindingToken(key)

        if case .confirmRun(let context) = branch {
            return handleConfirmRun(context, key: key)
        }

        if key == "escape" {
            cancelIdleTimer()
            onDismiss?(true, false)
            reset(scheduleIdleTimeout: false)
            return true
        }

        if key == "backspace" {
            switch branch {
            case .config(let prefix):
                guard !prefix.isEmpty else { return true }
                branch = .config(prefix: Array(prefix.dropLast()))
            case .runningApps:
                branch = .config(prefix: [])
            case .confirmRun:
                return true
            }
            refreshItems()
            armIdleTimer()
            return true
        }

        switch branch {
        case .confirmRun:
            return false

        case .runningApps(let snapshot):
            guard let entry = snapshot.first(where: { $0.key == key }) else { return false }
            RunningAppsProvider.activate(pid: entry.pid)
            cancelIdleTimer()
            onDismiss?(false, true)
            reset(scheduleIdleTimeout: false)
            return true

        case .config(let prefix):
            if prefix.isEmpty, key == "space" {
                branch = .runningApps(snapshot: RunningAppsProvider.snapshot())
                refreshItems()
                armIdleTimer()
                return true
            }

            let cfg = configStore.config
            let next = prefix + [key]

            if let action = cfg.bindings[next] {
                if case .run(_, _, _, let confirm?) = action.kind {
                    cancelIdleTimer()
                    branch = .confirmRun(ConfirmRunContext(
                        message: confirm,
                        action: action,
                        breadcrumbPrefix: Self.breadcrumbPrefix(for: branch)
                    ))
                    return true
                }
                executeAction(action)
                return true
            }

            let hasDescendant = cfg.bindings.keys.contains { path in
                path.count > next.count && Array(path.prefix(next.count)) == next
            }
            if hasDescendant {
                branch = .config(prefix: next)
                refreshItems()
                armIdleTimer()
                return true
            }

            return false
        }
    }

    private func handleConfirmRun(_ context: ConfirmRunContext, key: String) -> Bool {
        switch key {
        case "y", "Y":
            executeAction(context.action)
            return true
        case "n", "N", "escape":
            dismissPalette(restoreFocus: true)
            return true
        default:
            return false
        }
    }

    private func executeAction(_ action: Action) {
        let cfg = configStore.config
        ActionRunner.run(action, shellPath: cfg.shellPath, panel: cfg.panel)
        cancelIdleTimer()
        let focus = Self.focusDisposition(after: action)
        onDismiss?(focus.restoreFocus, focus.discardSavedFocus)
        reset(scheduleIdleTimeout: false)
    }

    private static func focusDisposition(after action: Action) -> (restoreFocus: Bool, discardSavedFocus: Bool) {
        switch action.kind {
        case .open, .url:
            return (false, true)
        case .run(_, let showOutput, _, _):
            return showOutput ? (false, false) : (true, false)
        }
    }
}
