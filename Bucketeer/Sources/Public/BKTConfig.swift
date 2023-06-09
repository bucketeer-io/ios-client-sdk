import UIKit

public struct BKTConfig {
    let apiKey: String
    let apiEndpoint: URL
    let featureTag: String
    let eventsFlushInterval: Int64
    let eventsMaxQueueSize: Int
    let pollingInterval: Int64
    let backgroundPollingInterval: Int64
    let sdkVersion: String
    let appVersion: String
    let logger: BKTLogger?
}

extension BKTConfig {
    public init(
        apiKey: String,
        apiEndpoint: String,
        featureTag: String,
        eventsFlushInterval: Int64 = Constant.DEFAULT_FLUSH_INTERVAL_MILLIS,
        eventsMaxQueueSize: Int = Constant.DEFAULT_MAX_QUEUE_SIZE,
        pollingInterval: Int64 = Constant.DEFAULT_POLLING_INTERVAL_MILLIS,
        backgroundPollingInterval: Int64 = Constant.DEFAULT_BACKGROUND_POLLING_INTERVAL_MILLIS,
        appVersion: String,
        logger: BKTLogger? = nil
    ) throws {
        guard !apiKey.isEmpty else {
            throw BKTError.illegalArgument(message: "apiKey is required")
        }
        guard let apiEndpointURL = URL(string: apiEndpoint) else {
            throw BKTError.illegalArgument(message: "endpoint is required")
        }
        guard !featureTag.isEmpty else {
            throw BKTError.illegalArgument(message: "featureTag is required")
        }
        guard !appVersion.isEmpty else {
            throw BKTError.illegalArgument(message: "appVersion is required")
        }

        var pollingInterval = pollingInterval
        if pollingInterval < Constant.MINIMUM_POLLING_INTERVAL_MILLIS {
            logger?.warn(message: "pollingInterval: \(pollingInterval) is set but must be above \(Constant.MINIMUM_POLLING_INTERVAL_MILLIS)")
            pollingInterval = Constant.MINIMUM_POLLING_INTERVAL_MILLIS
        }
        var backgroundPollingInterval = backgroundPollingInterval
        if backgroundPollingInterval < Constant.MINIMUM_BACKGROUND_POLLING_INTERVAL_MILLIS {
            logger?.warn(message: "backgroundPollingInterval: \(backgroundPollingInterval) is set but must be above \(Constant.MINIMUM_BACKGROUND_POLLING_INTERVAL_MILLIS)")
            backgroundPollingInterval = Constant.MINIMUM_BACKGROUND_POLLING_INTERVAL_MILLIS
        }
        var eventsFlushInterval = eventsFlushInterval
        if eventsFlushInterval < Constant.MINIMUM_FLUSH_INTERVAL_MILLIS {
            logger?.warn(message: "eventsFlushInterval: \(eventsFlushInterval) is set but must be above \(Constant.MINIMUM_FLUSH_INTERVAL_MILLIS)")
            eventsFlushInterval = Constant.DEFAULT_FLUSH_INTERVAL_MILLIS
        }

        self = BKTConfig(
            apiKey: apiKey,
            apiEndpoint: apiEndpointURL,
            featureTag: featureTag,
            eventsFlushInterval: eventsFlushInterval,
            eventsMaxQueueSize: eventsMaxQueueSize,
            pollingInterval: pollingInterval,
            backgroundPollingInterval: backgroundPollingInterval,
            sdkVersion: Version.current,
            appVersion: appVersion,
            logger: logger
        )
    }
}
