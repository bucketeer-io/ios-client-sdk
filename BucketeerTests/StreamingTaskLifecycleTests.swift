import XCTest
@testable import Bucketeer

/// `StreamingTask`: `reconnect()`, the user-attributes-updated flag, and the iOS lifecycle
/// (enable after the initial fetch, the same task reused across background/foreground, and
/// the SDK queue). The reconnect and flag tests are ported from the JS
/// `test/internal/streaming/StreamingTask.spec.ts`; the lifecycle ones are iOS only.
final class StreamingTaskLifecycleTests: XCTestCase {
    private var h: StreamingTaskHarness!

    override func setUp() {
        super.setUp()
        h = StreamingTaskHarness()
    }

    override func tearDown() {
        h.stop()
        h = nil
        super.tearDown()
    }

    // MARK: - User attributes flag

    func testOnOpenClearsTheFlagWithTheStateCapturedWhenTheRequestWasBuilt() {
        let captured = UserAttributesState(version: 1, isUpdated: true)
        h.setUserAttributesState(captured)
        h.startEnabled()

        h.openLatest()

        XCTAssertEqual(h.clearCalls, [captured])
    }

    // A newer setUserAttributesUpdated() between connect and open must survive. The task passes
    // the older captured state, and the storage refuses to clear with an old version
    // (EvaluationStorageTests covers that check).
    func testAFlagSetAfterTheRequestWasBuiltIsClearedOnlyWithTheOlderState() {
        let atBuild = UserAttributesState(version: 0, isUpdated: false)
        h.setUserAttributesState(atBuild)
        h.startEnabled()

        h.setUserAttributesState(.init(version: 1, isUpdated: true))
        h.openLatest()

        XCTAssertEqual(h.clearCalls, [atBuild])
    }

    func testAFailedConnectNeverClearsTheFlag() {
        h.setUserAttributesState(.init(version: 1, isUpdated: true))
        h.startEnabled()

        h.failLatest(status: 500) // never opened: retried after 1s
        h.advance(1_000)
        h.failLatest(status: 402) // the retry gives up

        XCTAssertEqual(h.sources.count, 2)
        XCTAssertEqual(h.fallbackStarts, [true])
        XCTAssertEqual(h.clearCalls, [])
    }

    // iOS only: updateUserAttributes() runs on the app's thread, while the request is built on
    // the SDK queue. The attributes state must be captured before the user is read. Then a
    // change in between can only make the captured state older than the attributes sent, which
    // leaves the flag set (safe). The other order could clear the flag for attributes the
    // request never carried.
    func testTheAttributesStateIsCapturedBeforeTheUserIsRead() throws {
        let userHolder = h.component.userHolder
        h.interactor.onReadUserAttributesState = { [unowned h] in
            // Plays updateUserAttributes() landing in the middle of the build.
            userHolder.updateAttributes { _ in ["plan": "premium"] }
            h!.interactor.onReadUserAttributesState = nil
            h!.interactor.currentUserAttributesState = .init(version: 1, isUpdated: true)
        }

        h.startEnabled()

        let user = try XCTUnwrap(h.latestBody()["user"] as? [String: Any])
        XCTAssertEqual(user["data"] as? [String: String], ["plan": "premium"])
    }

    // MARK: - reconnect()

    func testReconnectWhileStreamingOpensExactlyOneFreshConnectionWithFreshAttributes() throws {
        h.startEnabled()
        h.openLatest()

        h.updateUserAttributes(["plan": "premium"])
        h.reconnect()

        XCTAssertEqual(h.sources.count, 2)
        XCTAssertEqual(h.sources.first?.closed, true)
        let user = try XCTUnwrap(h.latestBody()["user"] as? [String: Any])
        XCTAssertEqual(user["data"] as? [String: String], ["plan": "premium"])
        // No old backoff or retry may open a third connection.
        h.advance(30_000)
        XCTAssertEqual(h.sources.count, 2)
    }

    func testReconnectRebuildsTheBodyWithTheLatestCachedState() throws {
        h.startEnabled()
        h.openLatest()

        // Storage moved on between the first connect and the reconnect.
        h.setCachedEvaluationsState(.init(userEvaluationsId: "updated_evaluations_id", evaluatedAt: "1700000999"))
        h.reconnect()

        let body = try h.latestBody()
        XCTAssertEqual(body["userEvaluationsId"] as? String, "updated_evaluations_id")
        XCTAssertEqual(body["evaluatedAt"] as? String, "1700000999")
    }

    func testReconnectFromTheFallbackGoesStraightBackToStreaming() {
        h.startEnabled()
        h.failLatest(status: 402)
        XCTAssertEqual(h.fallbackStarts, [true])

        h.reconnect()

        XCTAssertEqual(h.sources.count, 2)
        // The recovery was cancelled: only the new connection's watchdog is left.
        XCTAssertEqual(h.pendingTimers, 1)
        h.openLatest()
        XCTAssertEqual(h.fallbackStops, 1)
    }

    // Unlike a truly terminal error, a 413 can succeed once the app shrinks the attributes.
    func testReconnectAfterA413ReopensWithTheCorrectedAttributes() throws {
        h.startEnabled()
        h.failLatest(status: 413)
        XCTAssertEqual(h.fallbackStarts, [true])
        XCTAssertEqual(h.sources.count, 1)

        h.updateUserAttributes(["plan": "basic"])
        h.reconnect()

        XCTAssertEqual(h.sources.count, 2)
        let user = try XCTUnwrap(h.latestBody()["user"] as? [String: Any])
        XCTAssertEqual(user["data"] as? [String: String], ["plan": "basic"])
        h.openLatest()
        XCTAssertEqual(h.fallbackStops, 1)
    }

    func testReconnectAfterATerminalErrorIsANoOp() {
        h.startEnabled()
        h.failLatest(status: 401)
        XCTAssertEqual(h.fallbackStarts, [true])

        h.reconnect()

        // No new stream, and the fallback keeps polling on its own schedule, as in polling mode.
        XCTAssertEqual(h.sources.count, 1)
        XCTAssertEqual(h.fallbackStops, 0)
    }

    // MARK: - iOS lifecycle: the stream waits for enable()

    func testStartAloneDoesNotOpenUntilEnable() {
        h.start()
        XCTAssertEqual(h.sources.count, 0)

        h.enable()
        XCTAssertEqual(h.sources.count, 1)
    }

    func testEnableBeforeStartOpensOnStart() {
        h.enable()
        XCTAssertEqual(h.sources.count, 0)

        h.start()
        XCTAssertEqual(h.sources.count, 1)
    }

    func testReconnectBeforeEnableIsANoOp() {
        h.start()

        h.reconnect()

        XCTAssertEqual(h.sources.count, 0)
        XCTAssertEqual(h.fallbackStarts, [])
        // Control: once enabled, the stream opens.
        h.enable()
        XCTAssertEqual(h.sources.count, 1)
    }

    // MARK: - iOS lifecycle: the same task across foreground/background

    // TaskScheduler calls start() in its init and again on every didActivate notification.
    func testStartTwiceOpensOneStream() {
        h.startEnabled()
        h.start()
        XCTAssertEqual(h.sources.count, 1)
        XCTAssertEqual(h.latest?.openCount, 1)

        // Also while on the fallback: a second start() is not a reconnect.
        h.failLatest(status: 402)
        h.start()
        XCTAssertEqual(h.sources.count, 1)
        XCTAssertEqual(h.fallbackStarts, [true])
    }

    // JS builds a new task each time, so its terminalFailure starts false. iOS reuses the task,
    // so start() must not reset it: only destroy + initialize brings streaming back. Polling
    // resumes on foreground the way polling mode does, without an immediate fetch.
    func testTerminalFailureSurvivesStopAndStart() {
        h.startEnabled()
        h.failLatest(status: 401)

        h.stop()
        h.start()

        XCTAssertEqual(h.sources.count, 1)
        XCTAssertEqual(h.fallbackStarts, [true, false])
        h.reconnect()
        XCTAssertEqual(h.sources.count, 1)
    }

    // The reuse trap: background then foreground must build a new StreamConnection, not
    // restart the old one. A restarted connection would keep its unhealthy window, so the
    // new stream's first drop would give up at once.
    func testBackgroundThenForegroundCreatesANewConnection() {
        h.startEnabled()
        h.openLatest()
        h.failLatest() // unhealthy from t=0
        // Nothing answers the retries, so the watchdog keeps retrying. At 121s the connection
        // is past its 120s window but has not given up yet (no drop since).
        h.advance(121_000)
        XCTAssertEqual(h.fallbackStarts, [])
        h.stop()

        h.start()

        let sources = h.sources
        XCTAssertTrue(sources.dropLast().allSatisfy { $0.closed })
        XCTAssertNotNil(sources.last?.openedRequest, "the request is built again")
        XCTAssertFalse(sources.last?.closed ?? true)
        h.failLatest() // the new connection's first drop must retry, not give up
        XCTAssertEqual(h.fallbackStarts, [])
    }

    // MARK: - iOS threading: work runs on the SDK queue, shouldNotify is read on the main thread

    // Called from the main thread like TaskScheduler and BKTClient do. The request builder, the
    // event handlers, the storage write and the fallback must all run on the task's queue.
    func testEverythingRunsOnTheTaskQueueWhenCalledFromTheMainThread() {
        XCTAssertTrue(Thread.isMainThread)
        let lock = NSLock()
        var calls: [(name: String, onQueue: Bool)] = []
        let record: (String) -> Void = { [unowned h] name in
            let onQueue = h!.isOnQueue
            lock.withLock { calls.append((name, onQueue)) }
        }
        h.interactor.onCall = record
        h.onFallbackCall = record

        h.startEnabled()
        h.openLatest()
        h.emitOnLatest("put", StreamingTaskPayloads.valid())
        h.failLatest(status: 402)
        h.reconnect()
        h.openLatest()
        h.stop()
        // start() with the task already enabled opens the stream itself (in the order above,
        // enable() did). This is the call TaskScheduler makes on every foreground; the real
        // foreground path is checked in TaskSchedulerStreamingTests
        // (testBackgroundThenForegroundOpensANewStream).
        h.start()

        let recorded = lock.withLock { calls }
        XCTAssertEqual(Set(recorded.map { $0.name }), [
            "userAttributesState", "applyStreamedEvaluations", "clearUserAttributesUpdated",
            "fallback.start", "fallback.stop"
        ])
        XCTAssertEqual(recorded.filter { !$0.onQueue }.map { $0.name }, [])
    }

    // shouldNotify is read on the main thread (applyStreamedEvaluations) while the queue starts
    // and stops the task. The flag is behind a lock; a data race here shows up under Thread
    // Sanitizer, and the value must end consistent.
    func testShouldNotifyIsSafeToReadFromTheMainThreadWhileTheQueueRuns() throws {
        h.startEnabled()
        h.openLatest()
        h.emitOnLatest("put", StreamingTaskPayloads.valid())
        let shouldNotify = try XCTUnwrap(h.shouldNotifyHandlers.first)

        let task = h.task
        h.queue.async {
            for _ in 0..<1_000 {
                task.stop()
                task.start()
            }
        }
        for _ in 0..<1_000 {
            _ = shouldNotify()
        }
        h.drain()

        XCTAssertTrue(shouldNotify())
        XCTAssertTrue(task.isRunning)
    }
}
