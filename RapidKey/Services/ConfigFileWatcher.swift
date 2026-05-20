import Dispatch
import Foundation

/// Watches `rapidkey.toml` via vnode; debounces and notifies on disk changes (including atomic saves).
final class ConfigFileWatcher {
    private let url: URL
    private let onChange: () -> Void
    private let queue = DispatchQueue(label: "org.soniejka.RapidKey.configWatch", qos: .utility)

    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var debounceWorkItem: DispatchWorkItem?

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
    }

    func start() {
        queue.async { [weak self] in
            self?.openAndWatch()
        }
    }

    func stop() {
        queue.sync { [weak self] in
            self?.tearDownWatching()
        }
    }

    /// Stops the vnode source and closes the fd only. Does **not** cancel debounced `onChange`,
    /// so a pending reload (e.g. after config delete) is not wiped by `openAndWatch` retries.
    private func closeWatchSource() {
        if let source {
            source.setEventHandler {}
            source.cancel()
            self.source = nil
            // fd closed in cancel handler
        } else if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    private func tearDownWatching() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        closeWatchSource()
    }

    private func openAndWatch() {
        closeWatchSource()

        fileDescriptor = open(url.path, O_EVTONLY)
        if fileDescriptor < 0 {
            queue.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.openAndWatch()
            }
            return
        }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .delete, .rename, .attrib],
            queue: queue
        )

        src.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = src.data
            if flags.contains(.delete) || flags.contains(.rename) {
                self.queue.async { [weak self] in
                    guard let self else { return }
                    self.closeWatchSource()
                    self.queue.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                        self?.openAndWatch()
                    }
                    self.scheduleDebounce()
                }
            } else {
                self.scheduleDebounce()
            }
        }

        src.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        source = src
        src.resume()
    }

    private func scheduleDebounce() {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.onChange()
        }
        debounceWorkItem = work
        queue.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    deinit {
        stop()
    }
}
