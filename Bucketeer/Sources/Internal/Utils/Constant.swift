import Foundation

public struct Constant {
    static let MINIMUM_FLUSH_INTERVAL_MILLIS: Int64 = 60_000 // 60 seconds
    public static let DEFAULT_FLUSH_INTERVAL_MILLIS: Int64 = 60_000 // 60 seconds
    public static let DEFAULT_MAX_QUEUE_SIZE: Int = 50
    static let MINIMUM_POLLING_INTERVAL_MILLIS: Int64 = 60_000 // 60 seconds
    public static let DEFAULT_POLLING_INTERVAL_MILLIS: Int64 = 600_000 // 10 minutes
    static let MINIMUM_BACKGROUND_POLLING_INTERVAL_MILLIS: Int64 = 1_200_000 // 20 minutes
    public static let DEFAULT_BACKGROUND_POLLING_INTERVAL_MILLIS: Int64 = 3_600_000 // 1 hour

    struct DB {
        static let FILE_NAME = "bucketeer.db"
        static let VERSION: Int32 = 2
    }

    static let RETRY_POLLING_INTERVAL: Int64 = 60_000 // 60 seconds
    static let MAX_RETRY_COUNT = 5

    struct Streaming {
        // Must be longer than the backend heartbeat (25s) so a healthy stream never trips it.
        static let WATCHDOG_TIMEOUT_MILLIS: Int64 = 70_000
        // How long the connection may stay broken before giving up so the caller can fall back to polling.
        static let UNHEALTHY_FALLBACK_TIMEOUT_MILLIS: Int64 = 120_000
        // A connection open this long counts as stable: the next drop backs off from the start again.
        static let RESET_INTERVAL_MILLIS: Int64 = 60_000
        // URLSession idle timeout. Longer than the watchdog so our own timer fires first.
        static let REQUEST_TIMEOUT_SECONDS: TimeInterval = 90
    }
}
