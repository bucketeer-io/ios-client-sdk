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
}
