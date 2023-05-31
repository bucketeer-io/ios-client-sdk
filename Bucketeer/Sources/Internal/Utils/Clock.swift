import Foundation

protocol Clock {
    var currentTimeMillis: Int64 { get }
    var currentTimeSeconds: Int64 { get }
}

final class ClockImpl: Clock {
    var currentTimeMillis: Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }

    var currentTimeSeconds: Int64 {
        return Int64(Date().timeIntervalSince1970)
    }
}
