import XCTest
@testable import Bucketeer

final class StreamSchedulerTests: XCTestCase {

    // MARK: - DispatchStreamScheduler (real time, real queue)

    /// Production timers must run on the SDK queue, the one serial queue all streaming state lives on.
    func testDispatchSchedulerRunsWorkOnItsQueueAfterTheDelay() {
        let key = DispatchSpecificKey<String>()
        let queue = DispatchQueue(label: "io.bucketeer.test.streamScheduler")
        queue.setSpecific(key: key, value: "stream-queue")
        let scheduler = DispatchStreamScheduler(queue: queue)
        let ran = expectation(description: "work ran")
        var queueTag: String?
        var elapsedMillis: Int64 = -1

        let start = scheduler.nowMillis
        scheduler.schedule(afterMillis: 20, DispatchWorkItem {
            queueTag = DispatchQueue.getSpecific(key: key)
            elapsedMillis = scheduler.nowMillis - start
            ran.fulfill()
        })

        wait(for: [ran], timeout: 1)
        XCTAssertEqual(queueTag, "stream-queue")
        XCTAssertGreaterThanOrEqual(elapsedMillis, 20)
    }

    /// Timers cancelled on close must not fire. A later, uncancelled item proves the wait
    /// was long enough for the cancelled one to have run if it were going to.
    func testDispatchSchedulerCancelledWorkNeverRuns() {
        let queue = DispatchQueue(label: "io.bucketeer.test.streamScheduler")
        let scheduler = DispatchStreamScheduler(queue: queue)
        let cancelledRan = expectation(description: "cancelled work ran")
        cancelledRan.isInverted = true
        let laterRan = expectation(description: "later work ran")

        let cancelled = DispatchWorkItem { cancelledRan.fulfill() }
        scheduler.schedule(afterMillis: 20, cancelled)
        scheduler.schedule(afterMillis: 60, DispatchWorkItem { laterRan.fulfill() })
        cancelled.cancel()

        wait(for: [cancelledRan, laterRan], timeout: 0.5)
    }

    // MARK: - MockStreamScheduler (the fake clock every StreamConnection test relies on)

    /// Same meaning as JS `vi.advanceTimersByTime`: due work runs in time order (ties in
    /// scheduling order), and inside each item "now" is that item's due time.
    func testMockSchedulerRunsDueWorkInTimeOrder() {
        let scheduler = MockStreamScheduler()
        var ran: [String] = []

        for (name, delay) in [("30", Int64(30)), ("10", 10), ("20a", 20), ("20b", 20)] {
            scheduler.schedule(afterMillis: delay, DispatchWorkItem { [unowned scheduler] in
                ran.append("\(name)@\(scheduler.nowMillis)")
            })
        }
        scheduler.advance(byMillis: 30)

        XCTAssertEqual(ran, ["10@10", "20a@20", "20b@20", "30@30"])
        XCTAssertEqual(scheduler.nowMillis, 30)
        XCTAssertEqual(scheduler.pendingCount, 0)
    }

    /// The "advance 999, then 1" steps the JS StreamConnection tests rely on.
    func testMockSchedulerDoesNotRunWorkBeforeItIsDue() {
        let scheduler = MockStreamScheduler()
        var runCount = 0
        scheduler.schedule(afterMillis: 1_000, DispatchWorkItem { runCount += 1 })

        scheduler.advance(byMillis: 999)
        XCTAssertEqual(runCount, 0)
        XCTAssertEqual(scheduler.nowMillis, 999)

        scheduler.advance(byMillis: 1)
        XCTAssertEqual(runCount, 1)
        XCTAssertEqual(scheduler.nowMillis, 1_000)
    }

    /// Cancelled work never runs, and work scheduled from inside another item runs in the
    /// same `advance` when it falls inside the window (a reconnect scheduled by the watchdog
    /// must fire in the same step).
    func testMockSchedulerCancelAndNestedScheduling() {
        let scheduler = MockStreamScheduler()
        var ran: [String] = []

        let cancelled = DispatchWorkItem { ran.append("cancelled") }
        scheduler.schedule(afterMillis: 10, cancelled)
        scheduler.schedule(afterMillis: 20, DispatchWorkItem { [unowned scheduler] in
            ran.append("outer@\(scheduler.nowMillis)")
            scheduler.schedule(afterMillis: 30, DispatchWorkItem { [unowned scheduler] in
                ran.append("inner@\(scheduler.nowMillis)")
            })
            scheduler.schedule(afterMillis: 100, DispatchWorkItem { ran.append("late") })
        })
        cancelled.cancel()
        XCTAssertEqual(scheduler.pendingCount, 1)

        scheduler.advance(byMillis: 60)

        XCTAssertEqual(ran, ["outer@20", "inner@50"])
        XCTAssertEqual(scheduler.nowMillis, 60)
        XCTAssertEqual(scheduler.pendingCount, 1, "only the item due at 120 is left")
    }
}
