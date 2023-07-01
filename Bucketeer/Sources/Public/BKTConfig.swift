import UIKit

public class BKTConfig {
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

    internal init(apiKey: String,
                  apiEndpoint: URL,
                  featureTag: String,
                  eventsFlushInterval: Int64,
                  eventsMaxQueueSize: Int,
                  pollingInterval: Int64,
                  backgroundPollingInterval: Int64,
                  sdkVersion: String,
                  appVersion: String,
                  logger: BKTLogger? = nil) {
        self.apiKey = apiKey
        self.apiEndpoint = apiEndpoint
        self.featureTag = featureTag
        self.eventsFlushInterval = eventsFlushInterval
        self.eventsMaxQueueSize = eventsMaxQueueSize
        self.pollingInterval = pollingInterval
        self.backgroundPollingInterval = backgroundPollingInterval
        self.sdkVersion = sdkVersion
        self.appVersion = appVersion
        self.logger = logger
    }

    private convenience init(with builder: Builder) throws {
        guard let apiKeyForSDK = builder.apiKey, apiKeyForSDK.isNotEmpty() else {
            throw BKTError.illegalArgument(message: "apiKey is required")
        }
        guard let endpoint = builder.apiEndpoint, let apiEndpointURL = URL(string: endpoint) else {
            throw BKTError.illegalArgument(message: "endpoint is required")
        }
        guard let featureTag = builder.featureTag, featureTag.isNotEmpty() else {
            throw BKTError.illegalArgument(message: "featureTag is required")
        }
        guard let appVersion = builder.appVersion, appVersion.isNotEmpty() else {
            throw BKTError.illegalArgument(message: "appVersion is required")
        }

        var pollingInterval : Int64 = builder.pollingInterval ?? Constant.MINIMUM_POLLING_INTERVAL_MILLIS
        if pollingInterval < Constant.MINIMUM_POLLING_INTERVAL_MILLIS {
            builder.logger?.warn(message: "pollingInterval: \(pollingInterval) is set but must be above \(Constant.MINIMUM_POLLING_INTERVAL_MILLIS)")
            pollingInterval = Constant.MINIMUM_POLLING_INTERVAL_MILLIS
        }
        var backgroundPollingInterval : Int64 = builder.backgroundPollingInterval ?? Constant.MINIMUM_BACKGROUND_POLLING_INTERVAL_MILLIS
        if backgroundPollingInterval < Constant.MINIMUM_BACKGROUND_POLLING_INTERVAL_MILLIS {
            builder.logger?.warn(message: "backgroundPollingInterval: \(backgroundPollingInterval) is set but must be above \(Constant.MINIMUM_BACKGROUND_POLLING_INTERVAL_MILLIS)")
            backgroundPollingInterval = Constant.MINIMUM_BACKGROUND_POLLING_INTERVAL_MILLIS
        }
        var eventsFlushInterval: Int64 = builder.eventsFlushInterval ?? Constant.DEFAULT_FLUSH_INTERVAL_MILLIS
        if eventsFlushInterval < Constant.MINIMUM_FLUSH_INTERVAL_MILLIS {
            builder.logger?.warn(message: "eventsFlushInterval: \(eventsFlushInterval) is set but must be above \(Constant.MINIMUM_FLUSH_INTERVAL_MILLIS)")
            eventsFlushInterval = Constant.DEFAULT_FLUSH_INTERVAL_MILLIS
        }

        let eventsMaxQueueSize = builder.eventsMaxQueueSize ?? Constant.DEFAULT_MAX_QUEUE_SIZE

        self.init(apiKey: apiKeyForSDK,
                  apiEndpoint: apiEndpointURL,
                  featureTag: featureTag,
                  eventsFlushInterval: eventsFlushInterval,
                  eventsMaxQueueSize: eventsMaxQueueSize,
                  pollingInterval: pollingInterval,
                  backgroundPollingInterval: backgroundPollingInterval,
                  sdkVersion: Version.current,
                  appVersion: appVersion,
                  logger: builder.logger)
    }

    public class Builder {
        private(set) var apiKey: String?
        private(set) var apiEndpoint: String?
        private(set) var featureTag: String?
        private(set) var eventsFlushInterval: Int64?
        private(set) var eventsMaxQueueSize: Int?
        private(set) var pollingInterval: Int64?
        private(set) var backgroundPollingInterval: Int64?
        private(set) var appVersion: String?
        private(set) var logger: BKTLogger?

        /**
         * Create a new builder with your API key.
         */
        public init(apiKey: String) {
            self.apiKey = apiKey
        }

        public func with(apiKey: String) -> Builder {
            self.apiKey = apiKey
            return self
        }

        public func with(apiEndpoint: String) -> Builder {
            self.apiEndpoint = apiEndpoint
            return self
        }

        public func with(featureTag: String) -> Builder {
            self.featureTag = featureTag
            return self
        }

        public func with(eventsFlushInterval: Int64) -> Builder {
            self.eventsFlushInterval = eventsFlushInterval
            return self
        }

        public func with(eventsMaxQueueSize: Int) -> Builder {
            self.eventsMaxQueueSize = eventsMaxQueueSize
            return self
        }

        public func with(pollingInterval: Int64) -> Builder {
            self.pollingInterval = pollingInterval
            return self
        }

        public func with(backgroundPollingInterval: Int64) -> Builder {
            self.backgroundPollingInterval = backgroundPollingInterval
            return self
        }

        public func with(appVersion: String) -> Builder {
            self.appVersion = appVersion
            return self
        }

        public func with(logger: BKTLogger) -> Builder {
            self.logger = logger
            return self
        }

        public func build() throws -> BKTConfig {
            return try BKTConfig.init(with: self)
        }
    }
}

fileprivate extension String {
    func isNotEmpty() -> Bool {
        // We will not check all case
        return count > 0
    }
}
