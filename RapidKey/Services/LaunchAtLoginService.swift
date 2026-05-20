import os
import ServiceManagement

private let log = Logger(subsystem: "org.soniejka.RapidKey", category: "LaunchAtLogin")

enum LaunchAtLoginService {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Idempotently sets login item registration to match `enabled`.
    static func apply(_ enabled: Bool) {
        let svc = SMAppService.mainApp
        let want = enabled
        let have = svc.status == .enabled
        guard want != have else { return }
        do {
            if want {
                try svc.register()
            } else {
                try svc.unregister()
            }
        } catch {
            log.error("LaunchAtLogin apply(\(want)) failed: \(error.localizedDescription)")
        }
    }
}
