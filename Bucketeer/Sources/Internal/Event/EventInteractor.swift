import Foundation

protocol EventInteractor {
    func set(eventUpdateListener: EventUpdateListener?)
    func trackEvaluationEvent(featureTag: String, user: User, evaluation: Evaluation) throws
    func trackDefaultEvaluationEvent(featureTag: String, user: User, featureId: String) throws
    func trackGoalEvent(featureTag: String, user: User, goalId: String, value: Double) throws
    func trackFetchEvaluationsSuccess(featureTag: String, seconds: Double, sizeByte: Int64) throws
    func trackFetchEvaluationsFailure(featureTag: String, error: BKTError) throws
    func trackRegisterEventsFailure(error: BKTError) throws
    func sendEvents(force: Bool, completion: ((Result<Bool, BKTError>) -> Void)?)
}

extension EventInteractor {
    func sendEvents(completion: ((Result<Bool, BKTError>) -> Void)?) {
        self.sendEvents(force: false, completion: completion)
    }
}

final class EventInteractorImpl: EventInteractor {
    let sdkVersion: String
    let eventsMaxBatchQueueCount: Int
    let apiClient: ApiClient
    let eventDao: EventDao
    let clock: Clock
    let idGenerator: IdGenerator
    let logger: Logger?
    let featureTag: String

    private let metadata: [String: String]

    private var eventUpdateListener: EventUpdateListener?

    init(
        sdkVersion: String,
        appVersion: String,
        device: Device,
        eventsMaxBatchQueueCount: Int,
        apiClient: ApiClient,
        eventDao: EventDao,
        clock: Clock,
        idGenerator: IdGenerator,
        logger: Logger?,
        featureTag: String
    ) {
        self.sdkVersion = sdkVersion
        self.eventsMaxBatchQueueCount = eventsMaxBatchQueueCount
        self.apiClient = apiClient
        self.eventDao = eventDao
        self.clock = clock
        self.idGenerator = idGenerator
        self.logger = logger
        self.featureTag = featureTag
        self.metadata = [
            "app_version": appVersion,
            "os_version": device.osVersion,
            "device_model": device.model,
            "device_type": device.type
        ]
    }

    func set(eventUpdateListener: EventUpdateListener?) {
        self.eventUpdateListener = eventUpdateListener
    }

    func trackEvaluationEvent(featureTag: String, user: User, evaluation: Evaluation) throws {
        try eventDao.add(
            event: .init(
                id: idGenerator.id(),
                event: .evaluation(.init(
                    timestamp: clock.currentTimeSeconds,
                    featureId: evaluation.featureId,
                    featureVersion: evaluation.featureVersion,
                    userId: user.id,
                    variationId: evaluation.variationId,
                    user: user,
                    reason: evaluation.reason,
                    tag: featureTag,
                    sourceId: .ios,
                    sdkVersion: sdkVersion,
                    metadata: metadata
                )),
                type: .evaluation
            )
        )
        updateEventsAndNotify()
    }

    func trackDefaultEvaluationEvent(featureTag: String, user: User, featureId: String) throws {
        try eventDao.add(
            event: .init(
                id: idGenerator.id(),
                event: .evaluation(.init(
                    timestamp: clock.currentTimeSeconds,
                    featureId: featureId,
                    userId: user.id,
                    user: user,
                    reason: .init(type: .client),
                    tag: featureTag,
                    sourceId: .ios,
                    sdkVersion: sdkVersion,
                    metadata: metadata
                )),
                type: .evaluation
            )
        )
        updateEventsAndNotify()
    }

    func trackGoalEvent(featureTag: String, user: User, goalId: String, value: Double) throws {
        try eventDao.add(
            event: .init(
                id: idGenerator.id(),
                event: .goal(.init(
                    timestamp: clock.currentTimeSeconds,
                    goalId: goalId,
                    userId: user.id,
                    value: value,
                    user: user,
                    tag: featureTag,
                    sourceId: .ios,
                    sdkVersion: sdkVersion,
                    metadata: metadata
                )),
                type: .goal
            )
        )
        updateEventsAndNotify()
    }

    func trackFetchEvaluationsSuccess(featureTag: String, seconds: Double, sizeByte: Int64) throws {
        try eventDao.add(
            events: [
                .init(
                    id: idGenerator.id(),
                    event: .metrics(.init(
                        timestamp: clock.currentTimeSeconds,
                        event: .responseLatency(.init(
                            apiId: .getEvaluations,
                            labels: ["tag": featureTag],
                            latencySecond: seconds
                        )),
                        type: .responseLatency,
                        sourceId: .ios,
                        sdk_version: sdkVersion,
                        metadata: metadata
                    )),
                    type: .metrics
                ),
                .init(
                    id: idGenerator.id(),
                    event: .metrics(.init(
                        timestamp: clock.currentTimeSeconds,
                        event: .responseSize(.init(
                            apiId: .getEvaluations,
                            labels: ["tag": featureTag],
                            sizeByte: sizeByte
                        )),
                        type: .responseSize,
                        sourceId: .ios,
                        sdk_version: sdkVersion,
                        metadata: metadata
                    )),
                    type: .metrics
                )
            ]
        )
        updateEventsAndNotify()
    }

    func trackFetchEvaluationsFailure(featureTag: String, error: BKTError) throws {
        let metrics = metricsEvent(apiId: .getEvaluations, labels: ["tag": featureTag], error: error)
        try trackMetricsEvent(events: [
            .init(
                id: idGenerator.id(),
                event: metrics,
                type: .metrics
            )
        ])
    }

    func trackRegisterEventsFailure(error: BKTError) throws {
        // note: using the same tag in BKConfig.featureTag
        let metrics = metricsEvent(apiId: .registerEvents, labels: ["tag": featureTag], error: error)
        try trackMetricsEvent(events: [
            .init(
                id: idGenerator.id(),
                event: metrics,
                type: .metrics
            )
        ])
    }

    private func trackMetricsEvent(events : [Event]) throws {
        // We will add logic to filter duplicate metrics event here
        let storedEvents = try eventDao.getEvents()
        let metricsEventUniqueKeys : [String] = storedEvents.filter { item in
            return item.isMetricEvent()
        }.map { item in
            return item.uniqueKey()
        }
        let newEvents = events.filter { item in
            return item.isMetricEvent() && !metricsEventUniqueKeys.contains(item.uniqueKey())
        }
        if (newEvents.count > 0) {
            try eventDao.add(events: newEvents)
            updateEventsAndNotify()
        } else {
            logger?.debug(message: "no new events to add")
        }
    }

    func sendEvents(force: Bool, completion: ((Result<Bool, BKTError>) -> Void)?) {
        do {
            let currentEvents = try eventDao.getEvents()
            guard !currentEvents.isEmpty else {
                logger?.debug(message: "no events to register")
                completion?(.success(false))
                return
            }

            guard force || currentEvents.count >= eventsMaxBatchQueueCount else {
                logger?.debug(message: "event count is less than threshold - current: \(currentEvents.count), threshold: \(eventsMaxBatchQueueCount)")
                completion?(.success(false))
                return
            }
            let sendingEvents: [Event] = Array(currentEvents.prefix(eventsMaxBatchQueueCount))
            apiClient.registerEvents(events: sendingEvents) { [weak self] result in
                switch result {
                case .success(let response):
                    let errors = response.errors
                    let deletedIds: [String] = sendingEvents
                        .map { $0.id }
                        .filter({ eventId -> Bool in
                            guard let error = errors[eventId] else {
                                // if the event does not contain in error, delete it
                                return true
                            }
                            // if the error is not retriable, delete it
                            return !error.retriable
                        })
                    do {
                        try self?.eventDao.delete(ids: deletedIds)
                        self?.updateEventsAndNotify()
                        completion?(.success(true))
                    } catch let error {
                        completion?(.failure(BKTError(error: error)))
                    }
                case .failure(let error):
                    do {
                        try self?.trackRegisterEventsFailure(error: error)
                    } catch let error {
                        self?.logger?.error(error)
                    }
                    completion?(.failure(BKTError(error: error)))
                }
            }
        } catch let error {
            completion?(.failure(BKTError(error: error)))
        }
    }

    private func metricsEvent(apiId: ApiId, labels: [String: String], error: BKTError) -> EventData {
        let metricsEventData: MetricsEventData
        let metricsEventType: MetricsEventType
        switch error {
        case .timeout:
            metricsEventData = .timeoutError(.init(apiId: apiId, labels: labels))
            metricsEventType = .timeoutError
        case .network:
            metricsEventData = .networkError(.init(apiId: apiId, labels: labels))
            metricsEventType = .networkError
        case .badRequest:
            metricsEventData = .badRequestError(.init(apiId: apiId, labels: labels))
            metricsEventType = .badRequestError
        case .unauthorized:
            metricsEventData = .unauthorizedError(.init(apiId: apiId, labels: labels))
            metricsEventType = .unauthorizedError
        case .forbidden:
            metricsEventData = .forbiddenError(.init(apiId: apiId, labels: labels))
            metricsEventType = .forbiddenError
        case .notFound:
            metricsEventData = .notFoundError(.init(apiId: apiId, labels: labels))
            metricsEventType = .notFoundError
        case .clientClosed:
            metricsEventData = .clientClosedError(.init(apiId: apiId, labels: labels))
            metricsEventType = .clientClosedError
        case .unavailable:
            metricsEventData = .unavailableError(.init(apiId: apiId, labels: labels))
            metricsEventType = .unavailableError
        case .apiServer:
            metricsEventData = .internalServerError(.init(apiId: apiId, labels: labels))
            metricsEventType = .internalServerError
        case .unknownServer:
            metricsEventData = .unknownError(.init(apiId: apiId, labels: labels))
            metricsEventType = .unknownError
        default:
            metricsEventData = .internalSdkError(.init(apiId: apiId, labels: labels))
            metricsEventType = .internalError
        }
        return .metrics(.init(
            timestamp: clock.currentTimeSeconds,
            event: metricsEventData,
            type: metricsEventType,
            sourceId: .ios,
            sdk_version: sdkVersion,
            metadata: metadata
        ))
    }

    private func updateEventsAndNotify() {
        do {
            eventUpdateListener?.onUpdate(events: try eventDao.getEvents())
        } catch let error {
            logger?.error(error)
        }
    }
}

protocol EventUpdateListener {
    func onUpdate(events: [Event])
}

extension Event {
    func uniqueKey() -> String {
        switch event {
        case .metrics(let metric):
            switch metric.event {
            case .responseLatency(let mp):
                return mp.uniqueKey()
            case .responseSize(let mp):
                return mp.uniqueKey()
            case .timeoutError(let mp):
                return mp.uniqueKey()
            case .networkError(let mp):
                return mp.uniqueKey()
            case .badRequestError(let mp):
                return mp.uniqueKey()
            case .unauthorizedError(let mp):
                return mp.uniqueKey()
            case .forbiddenError(let mp):
                return mp.uniqueKey()
            case .notFoundError(let mp):
                return mp.uniqueKey()
            case .clientClosedError(let mp):
                return mp.uniqueKey()
            case .unavailableError(let mp):
                return mp.uniqueKey()
            case .internalSdkError(let mp):
                return mp.uniqueKey()
            case .internalServerError(let mp):
                return mp.uniqueKey()
            case .unknownError(let mp):
                return mp.uniqueKey()
            }
        default: return id
        }
    }
}
