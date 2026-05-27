import Foundation

struct RunningAppEntry: Equatable {
    let key: String
    let title: String
    let pid: pid_t
}
