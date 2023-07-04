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

        public init() {}

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

extension BKTConfig {
    // Public init - that will support to init of the BKTConfig like before we add the Builder.
    // So it will not create breaking changes
    @available(*, deprecated, message: "Use the Builder class instead. Check the documentation for more information.")
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
            throw BKTError.illegalArgument(message: "apiEndpoint is required")
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
        self.apiKey = apiKey
        self.apiEndpoint = apiEndpointURL
        self.featureTag = featureTag
        self.eventsFlushInterval = eventsFlushInterval
        self.eventsMaxQueueSize = eventsMaxQueueSize
        self.pollingInterval = pollingInterval
        self.backgroundPollingInterval = backgroundPollingInterval
        self.sdkVersion = Version.current
        self.appVersion = appVersion
        self.logger = logger
    }

    private init(with builder: Builder) throws {
        guard let apiKey = builder.apiKey, apiKey.isNotEmpty() else {
            throw BKTError.illegalArgument(message: "apiKey is required")
        }
        guard let apiEndpoint = builder.apiEndpoint, apiEndpoint.isNotEmpty() else {
            throw BKTError.illegalArgument(message: "apiEndpoint is required")
        }
        guard let featureTag = builder.featureTag, featureTag.isNotEmpty() else {
            throw BKTError.illegalArgument(message: "featureTag is required")
        }
        guard let appVersion = builder.appVersion, appVersion.isNotEmpty() else {
            throw BKTError.illegalArgument(message: "appVersion is required")
        }

        // Set default intervals if needed
        let pollingInterval : Int64 = builder.pollingInterval ?? Constant.MINIMUM_POLLING_INTERVAL_MILLIS
        let backgroundPollingInterval : Int64 = builder.backgroundPollingInterval ?? Constant.MINIMUM_BACKGROUND_POLLING_INTERVAL_MILLIS
        let eventsFlushInterval: Int64 = builder.eventsFlushInterval ?? Constant.DEFAULT_FLUSH_INTERVAL_MILLIS
        let eventsMaxQueueSize = builder.eventsMaxQueueSize ?? Constant.DEFAULT_MAX_QUEUE_SIZE

        // Use the current init method
        try self.init(apiKey: apiKey,
                      apiEndpoint: apiEndpoint,
                      featureTag: featureTag,
                      eventsFlushInterval: eventsFlushInterval,
                      eventsMaxQueueSize: eventsMaxQueueSize,
                      pollingInterval: pollingInterval,
                      backgroundPollingInterval: backgroundPollingInterval,
                      appVersion: appVersion,
                      logger: builder.logger)
    }
}

fileprivate extension String {
    func isNotEmpty() -> Bool {
        // We will not check all case
        return count > 0
    }
}
