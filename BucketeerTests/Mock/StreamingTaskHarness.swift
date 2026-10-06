import Foundation
@testable import Bucketeer

/// Records `start(immediately:)` and `stop()`, the iOS stand-in for the JS spies on
/// `EvaluationTask.prototype.start/stop`. Called only on the task's queue.
final class MockStreamingFallbackTask: StreamingFallbackTask {
    private(set) var startCalls: [Bool] = []
    private(set) var stopCount = 0
    /// Called with "fallback.start" / "fallback.stop", so a test can check which queue it ran on.
    var onCall: ((String) -> Void)?

    func start(immediately: Bool) {
        onCall?("fallback.start")
        startCalls.append(immediately)
    }

    func stop() {
        onCall?("fallback.stop")
        stopCount += 1
    }
}

/// Records every message, so a test can count warnings (`MockLogger` keeps only the last one).
final class RecordingLogger: Logger {
    private(set) var debugMessages: [String] = []
    private(set) var warnMessages: [String] = []
    private(set) var errors: [Error] = []

    func debug(message: String) {
        debugMessages.append(message)
    }

    func warn(message: String) {
        warnMessages.append(message)
    }

    func error(_ error: Error) {
        errors.append(error)
    }
}

/// The evaluation interactor as `StreamingTask` sees it. A class, not the `MockEvaluationInteractor`
/// struct: `MockComponent` would hold a copy of the struct, so a test could not change the cached
/// state or the attributes state between connects.
final class StreamingTaskTestInteractor: EvaluationInteractor {
    var cachedEvaluationsState = CachedEvaluationsState(userEvaluationsId: "", evaluatedAt: "0")
    var currentUserAttributesState = UserAttributesState(version: 0, isUpdated: false)
    /// Runs just before `userAttributesState` returns, so a test can play another thread
    /// changing the user in the middle of building the request.
    var onReadUserAttributesState: (() -> Void)?
    /// Called with the name of every interactor call, so a test can check which queue it ran on.
    var onCall: ((String) -> Void)?

    private(set) var applied: [GetEvaluationsResponse] = []
    private(set) var shouldNotifyHandlers: [() -> Bool] = []
    private(set) var clearCalls: [UserAttributesState] = []

    var userAttributesState: UserAttributesState {
        onCall?("userAttributesState")
        onReadUserAttributesState?()
        return currentUserAttributesState
    }

    func applyStreamedEvaluations(_ response: GetEvaluationsResponse, shouldNotify: @escaping () -> Bool) {
        onCall?("applyStreamedEvaluations")
        applied.append(response)
        shouldNotifyHandlers.append(shouldNotify)
    }

    @discardableResult func clearUserAttributesUpdated(state: UserAttributesState) -> Bool {
        onCall?("clearUserAttributesUpdated")
        clearCalls.append(state)
        return true
    }

    func fetch(user: User, timeoutMillis: Int64?, completion: ((GetEvaluationsResult) -> Void)?) {}
    func getLatest(userId: String, featureId: String) -> Evaluation? { nil }
    func refreshCache() throws {}
    func setUserAttributesUpdated() {}
    func addUpdateListener(listener: EvaluationUpdateListener) -> String { "" }
    func removeUpdateListener(key: String) {}
    func clearUpdateListeners() {}
}

/// The test `StreamingTaskDependencies`: a fake clock, a pinned backoff, and a record of every event source
/// and fallback the task creates (like JS `FakeEventSource.instances`). Its lists are only touched
/// on `queue`.
final class MockStreamingTaskDependencies: StreamingTaskDependencies {
    let queue = DispatchQueue(label: "io.bucketeer.test.StreamingTask")
    let mockScheduler = MockStreamScheduler()
    /// Passed to every fallback created after it is set.
    var onFallbackCall: ((String) -> Void)?

    private(set) var sources: [MockEventSource] = []
    private(set) var fallbacks: [MockStreamingFallbackTask] = []

    var scheduler: StreamScheduler { mockScheduler }

    func makeEventSource() -> EventSource {
        let source = MockEventSource()
        sources.append(source)
        return source
    }

    func makeFallbackTask() -> StreamingFallbackTask {
        let fallback = MockStreamingFallbackTask()
        fallback.onCall = onFallbackCall
        fallbacks.append(fallback)
        return fallback
    }

    /// Jitter pinned to 0, so retry delays are exactly 1s, 2s, 4s, ... 30s.
    func makeBackoff() -> StreamBackoff {
        return StreamBackoff(random: { 0 })
    }
}

extension UserAttributesState: Equatable {
    public static func == (lhs: UserAttributesState, rhs: UserAttributesState) -> Bool {
        lhs.version == rhs.version && lhs.isUpdated == rhs.isUpdated
    }
}

/// Shared setup for the `StreamingTask` tests: a real `StreamingTask` built with a
/// `MockStreamingTaskDependencies` (its queue tagged, so a test can check what ran on it), and a
/// recording interactor and logger.
///
/// Production threading: the task's entry points are called from the test (main) thread and
/// hop onto the queue on their own, then `drain()` waits for them. Everything else that touches
/// the task's state (driving an event source, advancing the clock, reading what was recorded)
/// runs inside `queue.sync`.
final class StreamingTaskHarness {
    let queueKey = DispatchSpecificKey<Void>()
    let dependencies = MockStreamingTaskDependencies()
    let logger = RecordingLogger()
    let interactor = StreamingTaskTestInteractor()
    let component: MockComponent

    init(config: BKTConfig = .mock(featureTag: "feature_tag_value")) {
        let logger = self.logger
        component = MockComponent(
            config: config.withLogger(logger),
            evaluationInteractor: interactor
        )
        queue.setSpecific(key: queueKey, value: ())
    }

    lazy var task = StreamingTask(component: component, dependencies: dependencies)

    var queue: DispatchQueue { dependencies.queue }
    private var _sources: [MockEventSource] { dependencies.sources }
    private var _fallbacks: [MockStreamingFallbackTask] { dependencies.fallbacks }

    /// Passed to every fallback the task creates. Set it before the task starts.
    var onFallbackCall: ((String) -> Void)? {
        get { dependencies.onFallbackCall }
        set { dependencies.onFallbackCall = newValue }
    }

    var isOnQueue: Bool {
        DispatchQueue.getSpecific(key: queueKey) != nil
    }

    // MARK: - Entry points, called like TaskScheduler does (off the queue)

    /// `start()` then `enable()`, the order the SDK uses: the stream opens after the initial fetch.
    func startEnabled() {
        task.start()
        task.enable()
        drain()
    }

    func start() {
        task.start()
        drain()
    }

    func enable() {
        task.enable()
        drain()
    }

    func stop() {
        task.stop()
        drain()
    }

    func reconnect() {
        task.reconnect()
        drain()
    }

    /// Waits until everything already queued has run.
    func drain() {
        queue.sync {}
    }

    // MARK: - Server side and clock, on the queue

    func openLatest() {
        queue.sync { _sources.last?.simulateOpen() }
    }

    func failLatest(status: Int? = nil) {
        queue.sync { _sources.last?.simulateError(status: status) }
    }

    func emitOnLatest(_ type: String, _ data: String) {
        queue.sync { _sources.last?.emit(type, data) }
    }

    func messageOnLatest(_ data: String) {
        queue.sync { _sources.last?.simulateMessage(data) }
    }

    func bytesOnLatest() {
        queue.sync { _sources.last?.simulateBytes() }
    }

    /// Holds the queue until the returned semaphore is signalled, so a test can line up blocks
    /// behind it.
    func blockQueue() -> DispatchSemaphore {
        let blocker = DispatchSemaphore(value: 0)
        queue.async { blocker.wait() }
        return blocker
    }

    /// Queues `body` with the latest event source without waiting for it, like a URLSession
    /// callback that is already waiting in the queue.
    func enqueueOnLatest(_ body: @escaping (MockEventSource) -> Void) {
        queue.async { [unowned self] in
            if let source = self._sources.last { body(source) }
        }
    }

    func advance(_ millis: Int64) {
        queue.sync { dependencies.mockScheduler.advance(byMillis: millis) }
    }

    /// Changes the user the way `BKTClient.updateUserAttributes` does, on the queue so it can't
    /// overlap a request build (a test that wants the overlap uses `onReadUserAttributesState`).
    func updateUserAttributes(_ data: [String: String]) {
        queue.sync { component.userHolder.updateAttributes { _ in data } }
    }

    func setCachedEvaluationsState(_ state: CachedEvaluationsState) {
        queue.sync { interactor.cachedEvaluationsState = state }
    }

    func setUserAttributesState(_ state: UserAttributesState) {
        queue.sync { interactor.currentUserAttributesState = state }
    }

    // MARK: - What happened, read on the queue

    var sources: [MockEventSource] { queue.sync { _sources } }
    var latest: MockEventSource? { queue.sync { _sources.last } }
    var pendingTimers: Int { queue.sync { dependencies.mockScheduler.pendingCount } }
    var applied: [GetEvaluationsResponse] { queue.sync { interactor.applied } }
    var clearCalls: [UserAttributesState] { queue.sync { interactor.clearCalls } }
    var shouldNotifyHandlers: [() -> Bool] { queue.sync { interactor.shouldNotifyHandlers } }
    var warnings: [String] { queue.sync { logger.warnMessages } }

    /// Every `start(immediately:)` on every fallback the task created, in order.
    var fallbackStarts: [Bool] { queue.sync { _fallbacks.flatMap { $0.startCalls } } }
    /// Every `stop()` on every fallback the task created.
    var fallbackStops: Int { queue.sync { _fallbacks.reduce(0) { $0 + $1.stopCount } } }

    /// The JSON body of the latest request, decoded to a dictionary.
    func latestBody() throws -> [String: Any] {
        let data = queue.sync { _sources.last?.openedRequest?.httpBody } ?? Data()
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}

// MARK: - Payloads

enum StreamingTaskPayloads {
    /// A valid `put`/`patch` payload: `GetEvaluationsResponse` with `UserEvaluations.mock1`.
    static func valid(userEvaluationsId: String = "user_evaluation_id_value") -> String {
        let response = GetEvaluationsResponse(evaluations: .mock1, userEvaluationsId: userEvaluationsId)
        // swiftlint:disable:next force_try
        return String(data: try! JSONEncoder().encode(response), encoding: .utf8)!
    }
}

extension BKTConfig {
    /// Same config with another logger, so a test can read what the task logged.
    func withLogger(_ logger: BKTLogger) -> BKTConfig {
        return BKTConfig(
            apiKey: apiKey,
            apiEndpoint: apiEndpoint,
            featureTag: featureTag,
            eventsFlushInterval: eventsFlushInterval,
            eventsMaxQueueSize: eventsMaxQueueSize,
            pollingInterval: pollingInterval,
            backgroundPollingInterval: backgroundPollingInterval,
            sourceId: sourceId,
            sdkVersion: sdkVersion,
            appVersion: appVersion,
            logger: logger,
            enableStreaming: enableStreaming
        )
    }
}
