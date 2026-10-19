import XCTest
@testable import Bucketeer

/// `StreamingTask`: what happens when the stream gives up, the polling fallback, and the
/// 5-minute recovery. Ported from the JS `test/internal/streaming/StreamingTask.spec.ts`.
///
/// 402 is used as "an unclassified 4xx": neither terminal nor recoverable, so the connection
/// gives up on the first error, with no backoff retry.
final class StreamingTaskFallbackTests: XCTestCase {
    private let recoveryMillis: Int64 = 300_000
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

    // MARK: - Giving up

    func testNonTerminalErrorStartsTheFallbackImmediatelyAndArmsRecovery() {
        h.startEnabled()

        h.failLatest(status: 402)

        // Fetch right away, not one pollingInterval later.
        XCTAssertEqual(h.fallbackStarts, [true])
        h.advance(recoveryMillis)
        XCTAssertEqual(h.sources.count, 2)
        h.openLatest()
        XCTAssertEqual(h.fallbackStops, 1)
    }

    func testBodyDependent4xxStartsTheFallbackAndArmsRecoveryLikeAnyNonTerminalError() {
        for status in [400, 413, 422] {
            let h = StreamingTaskHarness()
            h.startEnabled()

            h.failLatest(status: status)

            XCTAssertEqual(h.fallbackStarts, [true], "status \(status)")
            h.advance(recoveryMillis)
            XCTAssertEqual(h.sources.count, 2, "status \(status)")
            h.openLatest()
            XCTAssertEqual(h.fallbackStops, 1, "status \(status)")
            h.stop()
        }
    }

    func testTerminalErrorStartsTheFallbackButNeverSchedulesRecovery() {
        h.startEnabled()

        h.failLatest(status: 401)

        XCTAssertEqual(h.fallbackStarts, [true])
        XCTAssertEqual(h.pendingTimers, 0)
        h.advance(30 * 60_000)
        XCTAssertEqual(h.sources.count, 1)
    }

    func testUnhealthyPast120sWithNoStatusStartsTheFallback() {
        h.startEnabled()
        h.openLatest()
        h.failLatest() // a drop with no status: the unhealthy clock starts here

        // Backoff 1, 2, 4, 8, 16, 30, 30s (jitter pinned to 0). The fallback must wait for the
        // whole 120s window, not start on an early drop.
        for delaySeconds: Int64 in [1, 2, 4, 8, 16, 30, 30] {
            h.advance(delaySeconds * 1_000)
            XCTAssertEqual(h.fallbackStarts, [], "after \(delaySeconds)s")
            h.failLatest()
        }
        h.advance(30_000) // 121s since the first failure
        h.failLatest()

        XCTAssertEqual(h.fallbackStarts, [true])
    }

    func testTerminalGiveUpWarnsOnce() {
        h.startEnabled()

        h.failLatest(status: 401)

        XCTAssertEqual(h.fallbackStarts, [true])
        XCTAssertEqual(h.warnings.count, 1)
    }

    func testNonTerminalGiveUpDoesNotWarn() {
        h.startEnabled()

        h.failLatest(status: 402)

        XCTAssertEqual(h.fallbackStarts, [true])
        XCTAssertEqual(h.warnings, [])
    }

    // MARK: - Recovery

    func testOnOpenAfterRecoveryStopsTheFallbackAndLeavesNoRecoveryPending() {
        h.startEnabled()
        h.failLatest(status: 402)
        h.advance(recoveryMillis)
        XCTAssertEqual(h.sources.count, 2)

        h.openLatest()

        XCTAssertEqual(h.fallbackStops, 1)
        // Only the connection's own timers are left (watchdog + backoff reset).
        XCTAssertEqual(h.pendingTimers, 2)
    }

    func testRecoveryReopeningKeepsTheFallbackUntilOnOpen() {
        h.startEnabled()
        h.failLatest(status: 402)
        XCTAssertEqual(h.fallbackStarts, [true])

        h.advance(recoveryMillis)

        XCTAssertEqual(h.sources.count, 2)
        // The new stream hasn't opened yet: polling must keep running, no gap.
        XCTAssertEqual(h.fallbackStops, 0)
        h.openLatest()
        XCTAssertEqual(h.fallbackStops, 1)
    }

    func testReconnectFromTheFallbackKeepsTheFallbackUntilOnOpen() {
        h.startEnabled()
        h.failLatest(status: 402)
        XCTAssertEqual(h.fallbackStarts, [true])

        h.reconnect()

        XCTAssertEqual(h.sources.count, 2)
        XCTAssertEqual(h.fallbackStops, 0)
        h.openLatest()
        XCTAssertEqual(h.fallbackStops, 1)
    }

    func testReconnectOpenedStreamPlusAnArmedRecoveryGivesOneLiveConnection() {
        h.startEnabled()
        h.failLatest(status: 402) // recovery armed for +5 min
        h.reconnect() // opens a new stream while the recovery is still pending
        XCTAssertEqual(h.sources.count, 2)
        h.openLatest()

        // Keep the new connection healthy so its own watchdog never reconnects. Only the old
        // recovery could open a third connection here.
        for _ in 0..<5 {
            h.advance(60_000)
            h.bytesOnLatest()
        }

        XCTAssertEqual(h.sources.count, 2)
    }

    // onOpen clears the recovery too, so the test above does not prove that openStream() cancels
    // it. Here the reconnect-opened stream never opens: it fails terminally, and only
    // openStream()'s own cancel can stop the old recovery from reopening a dead stream.
    func testTerminalErrorOnAReconnectOpenedStreamLeavesNoRecovery() {
        h.startEnabled()
        h.failLatest(status: 402) // recovery armed
        h.reconnect()
        XCTAssertEqual(h.sources.count, 2)

        h.failLatest(status: 401)

        h.advance(recoveryMillis)
        XCTAssertEqual(h.sources.count, 2)
    }

    // MARK: - stop()

    func testStopStopsTheConnectionTheFallbackAndRecovery() {
        h.startEnabled()
        h.failLatest(status: 402)

        h.stop()

        XCTAssertFalse(h.task.isRunning)
        XCTAssertEqual(h.fallbackStops, 1)
        XCTAssertEqual(h.pendingTimers, 0)
        h.advance(30 * 60_000)
        XCTAssertEqual(h.sources.count, 1)
    }

    // iOS only: BKTClient.destroy() calls stop() through TaskScheduler.invalidate() and then drops
    // the scheduler, so the task can be released before stop()'s queued cleanup runs. The
    // cleanup must still close the stream: URLSession keeps its delegate (the event source)
    // alive until it is invalidated, so an unclosed stream would stay open after destroy.
    func testStopClosesTheStreamEvenWhenTheTaskIsReleasedRightAway() {
        var task: StreamingTask? = StreamingTask(component: h.component, dependencies: h.dependencies)
        task?.start()
        task?.enable()
        h.drain()
        h.openLatest()
        weak var releasedTask = task
        let blocker = h.blockQueue()

        task?.stop()
        task = nil // what TaskScheduler.invalidate() + BKTClient.destroy() do
        blocker.signal()
        h.drain()

        XCTAssertEqual(h.sources.count, 1)
        XCTAssertEqual(h.latest?.closed, true)
        XCTAssertNil(releasedTask, "released once the cleanup has run")
    }
}
