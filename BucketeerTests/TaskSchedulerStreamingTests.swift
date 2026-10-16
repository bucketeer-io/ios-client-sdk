import XCTest
import UIKit
@testable import Bucketeer

/// `TaskScheduler` with streaming on: which task it runs, `enableEvaluationTask()`, user attribute
/// updates (merged by `StreamingTask` into one reconnect after 200ms), and the app lifecycle. Ported from the JS
/// `test/internal/scheduler/TaskScheduler.spec.ts` where JS has the same behavior; the lifecycle
/// tests are iOS only (JS has no background/foreground step).
final class TaskSchedulerStreamingTests: XCTestCase {
    private var dependencies: MockStreamingTaskDependencies!
    private var interactor: StreamingTaskTestInteractor!
    private var scheduler: TaskScheduler?

    override func setUp() {
        super.setUp()
        dependencies = MockStreamingTaskDependencies()
        interactor = StreamingTaskTestInteractor()
    }

    override func tearDown() {
        scheduler?.stop()
        drain()
        scheduler = nil
        super.tearDown()
    }

    // MARK: - Which task runs

    func testStreamingConfigUsesStreamingTask() {
        let scheduler = makeScheduler(enableStreaming: true)

        XCTAssertEqual(scheduler.foregroundSchedulers.filter { $0 is StreamingTask }.count, 1)
        XCTAssertEqual(scheduler.foregroundSchedulers.filter { $0 is EvaluationForegroundTask }.count, 0)
        XCTAssertEqual(scheduler.foregroundSchedulers.filter { $0 is EventForegroundTask }.count, 1)
    }

    func testPollingConfigKeepsEvaluationForegroundTask() {
        let scheduler = makeScheduler(enableStreaming: false)

        XCTAssertEqual(scheduler.foregroundSchedulers.filter { $0 is StreamingTask }.count, 0)
        XCTAssertEqual(scheduler.foregroundSchedulers.filter { $0 is EvaluationForegroundTask }.count, 1)
        XCTAssertEqual(scheduler.foregroundSchedulers.filter { $0 is EventForegroundTask }.count, 1)
    }

    // The only test of the production dependencies: everything is built on the SDK queue.
    func testDefaultStreamingDependenciesAreBuiltOnTheSDKQueue() throws {
        let queue = DispatchQueue(label: "io.bucketeer.test.TaskSchedulerStreaming.default")
        let component = MockComponent(config: .mock(enableStreaming: true), evaluationInteractor: interactor)
        let scheduler = TaskScheduler(component: component, dispatchQueue: queue)
        self.scheduler = scheduler

        let dependencies = try XCTUnwrap(scheduler.streamingTaskDependencies as? StreamingTaskDependenciesImpl)
        XCTAssertTrue(dependencies.queue === queue)
        XCTAssertTrue(dependencies.scheduler is DispatchStreamScheduler)
        XCTAssertTrue(dependencies.makeEventSource() is URLSessionEventSource)
        let fallback = try XCTUnwrap(dependencies.makeFallbackTask() as? EvaluationForegroundTask)
        XCTAssertTrue(fallback.isTaskEnabled, "the fallback starts after the initial fetch, so it is created enabled")
    }

    // MARK: - enableEvaluationTask()

    // iOS only: the stream waits for the initial fetch, through the same switch polling uses.
    func testEnableEvaluationTaskEnablesStreamingTask() {
        let scheduler = makeScheduler(enableStreaming: true)
        drain()
        XCTAssertEqual(sources.count, 0, "started by init, but not enabled yet")

        scheduler.enableEvaluationTask()
        drain()

        XCTAssertEqual(sources.count, 1)
    }

    // MARK: - onUserAttributesUpdated()

    func testUserAttributesUpdatesMergeIntoOneReconnectAfter200ms() {
        let scheduler = makeStreamingSchedulerWithAnOpenStream()

        scheduler.onUserAttributesUpdated()
        scheduler.onUserAttributesUpdated()
        scheduler.onUserAttributesUpdated()
        drain()

        advance(199)
        XCTAssertEqual(sources.count, 1)
        advance(1)
        XCTAssertEqual(sources.count, 2, "exactly one reconnect, 200ms after the last call")
        advance(1_000)
        XCTAssertEqual(sources.count, 2)
    }

    func testUserAttributesUpdateIsANoOpWhenPolling() {
        let scheduler = makeScheduler(enableStreaming: false)
        scheduler.enableEvaluationTask()

        scheduler.onUserAttributesUpdated()
        drain()

        XCTAssertEqual(pendingTimers, 0)
        advance(1_000)
        XCTAssertEqual(sources.count, 0)
    }

    func testStopCancelsAPendingReconnect() {
        let scheduler = makeStreamingSchedulerWithAnOpenStream()
        scheduler.onUserAttributesUpdated()
        drain()
        XCTAssertGreaterThan(pendingTimers, 0)

        scheduler.stop()
        drain()

        XCTAssertEqual(pendingTimers, 0)
        advance(1_000)
        XCTAssertEqual(sources.count, 1)
    }

    // MARK: - App lifecycle (iOS only)

    // The reuse trap, through the real notifications: the same StreamingTask comes back on
    // foreground, and it must open a new stream instead of reusing the closed one. The
    // notifications arrive on the main thread, so this also checks that the foreground open
    // (the request build) runs on the SDK queue.
    func testBackgroundThenForegroundOpensANewStream() {
        _ = makeStreamingSchedulerWithAnOpenStream()

        leaveApp()
        drain()
        XCTAssertEqual(sources.first?.closed, true)

        let queueKey = DispatchSpecificKey<Void>()
        dependencies.queue.setSpecific(key: queueKey, value: ())
        let lock = NSLock()
        var calls: [(name: String, onQueue: Bool)] = []
        interactor.onCall = { name in
            let onQueue = DispatchQueue.getSpecific(key: queueKey) != nil
            lock.withLock { calls.append((name, onQueue)) }
        }
        XCTAssertTrue(Thread.isMainThread)
        returnToApp()
        drain()

        XCTAssertEqual(sources.count, 2)
        XCTAssertEqual(sources.last?.closed, false)
        XCTAssertNotNil(sources.last?.openedRequest)
        let recorded = lock.withLock { calls }
        XCTAssertTrue(recorded.contains { $0.name == "userAttributesState" }, "the request was built")
        XCTAssertEqual(recorded.filter { !$0.onQueue }.map { $0.name }, [])
    }

    // A sequence that is easy to get wrong: the user changes while the app is in the background.
    // Nothing may open a stream in the background, and the foreground stream must carry the new
    // attributes.
    func testUserAttributesUpdatedWhileBackgroundedAreSentOnForeground() throws {
        let scheduler = makeStreamingSchedulerWithAnOpenStream()
        leaveApp()
        drain()

        dependencies.queue.sync { scheduler.component.userHolder.updateAttributes { _ in ["plan": "premium"] } }
        scheduler.onUserAttributesUpdated()
        drain()
        advance(1_000)
        XCTAssertEqual(sources.count, 1, "no stream may open in the background")

        returnToApp()
        drain()
        advance(1_000)

        XCTAssertEqual(sources.count, 2)
        let body = try XCTUnwrap(dependencies.queue.sync { dependencies.sources.last?.openedRequest?.httpBody })
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let user = try XCTUnwrap(json["user"] as? [String: Any])
        XCTAssertEqual(user["data"] as? [String: String], ["plan": "premium"])
    }

    // BKTClient.destroy() calls invalidate() and then drops the scheduler. The stream must be
    // closed, and stream data after that must not reach storage, so a destroyed client's stream
    // can't write.
    func testDestroyClosesTheStreamAndDropsLaterData() {
        let scheduler = makeStreamingSchedulerWithAnOpenStream()

        scheduler.invalidate()
        self.scheduler = nil
        drain()

        XCTAssertEqual(sources.first?.closed, true)
        dependencies.queue.sync { dependencies.sources.first?.emit("put", StreamingTaskPayloads.valid()) }
        XCTAssertEqual(dependencies.queue.sync { interactor.applied.count }, 0)
    }

    // A short interruption (an alert, Control Center) is not a trip to the background: UIKit posts
    // "will resign active" and "did become active" with no background step in between.
    func testInterruptionKeepsTheStreamOpen() {
        _ = makeStreamingSchedulerWithAnOpenStream()

        postInterruption()
        drain()

        XCTAssertEqual(sources.count, 1, "no new stream")
        XCTAssertEqual(sources.first?.closed, false, "the stream stays open")
    }

    func testOnlyARealBackgroundFlushesEventsWhenPolling() {
        assertOnlyARealBackgroundFlushesEvents(enableStreaming: false)
    }

    func testOnlyARealBackgroundFlushesEventsWhenStreaming() {
        assertOnlyARealBackgroundFlushesEvents(enableStreaming: true)
    }

    // "Did become active" alone is not a return to the app: only "will enter foreground" is.
    func testOldForegroundEventDoesNotReopenTheStream() {
        _ = makeStreamingSchedulerWithAnOpenStream()
        leaveApp()
        drain()
        XCTAssertEqual(sources.first?.closed, true)

        postBecomeActive()
        drain()

        XCTAssertEqual(sources.count, 1, "did become active alone opens nothing")
    }

    // MARK: - Helpers

    private var sources: [MockEventSource] { dependencies.queue.sync { dependencies.sources } }
    private var pendingTimers: Int { dependencies.queue.sync { dependencies.mockScheduler.pendingCount } }

    private func makeScheduler(
        enableStreaming: Bool,
        eventInteractor: EventInteractor = MockEventInteractor()
    ) -> TaskScheduler {
        let component = MockComponent(
            config: .mock(enableStreaming: enableStreaming),
            evaluationInteractor: interactor,
            eventInteractor: eventInteractor
        )
        let scheduler = TaskScheduler(
            component: component,
            dispatchQueue: dependencies.queue,
            streamingTaskDependencies: dependencies
        )
        self.scheduler = scheduler
        return scheduler
    }

    private func makeStreamingSchedulerWithAnOpenStream() -> TaskScheduler {
        let scheduler = makeScheduler(enableStreaming: true)
        scheduler.enableEvaluationTask()
        drain()
        dependencies.queue.sync { dependencies.sources.last?.simulateOpen() }
        XCTAssertEqual(sources.count, 1)
        return scheduler
    }

    private func drain() {
        dependencies.queue.sync {}
    }

    private func advance(_ millis: Int64) {
        dependencies.queue.sync { dependencies.mockScheduler.advance(byMillis: millis) }
    }

    private func assertOnlyARealBackgroundFlushesEvents(
        enableStreaming: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var forcedFlushes = 0
        let events = MockEventInteractor(sendEventsHandler: { force, _ in
            if force { forcedFlushes += 1 }
        })
        _ = makeScheduler(enableStreaming: enableStreaming, eventInteractor: events)

        postInterruption()
        drain()
        XCTAssertEqual(dependencies.queue.sync { forcedFlushes }, 0, "an interruption does not flush", file: file, line: line)

        leaveApp()
        drain()
        XCTAssertEqual(dependencies.queue.sync { forcedFlushes }, 1, "leaving the app flushes once", file: file, line: line)
    }

    // The order UIKit posts them in. An interruption has no background step. The old
    // "active" events are posted too, so a test fails if the scheduler still listens to them.
    private func postInterruption() {
        postResignActive()
        postBecomeActive()
    }

    private func leaveApp() {
        postResignActive()
        post(UIApplication.didEnterBackgroundNotification)
    }

    private func returnToApp() {
        post(UIApplication.willEnterForegroundNotification)
        postBecomeActive()
    }

    private func postResignActive() {
        post(UIApplication.willResignActiveNotification)
        if #available(iOS 13.0, tvOS 13.0, *) {
            post(UIScene.willDeactivateNotification)
        }
    }

    private func postBecomeActive() {
        if #available(iOS 13.0, tvOS 13.0, *) {
            post(UIScene.didActivateNotification)
        }
        post(UIApplication.didBecomeActiveNotification)
    }

    private func post(_ name: Notification.Name) {
        NotificationCenter.default.post(name: name, object: nil)
    }
}
