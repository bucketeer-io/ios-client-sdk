import XCTest
@testable import Bucketeer

/// Timing rules of `StreamConnection`:
/// the 70s silence watchdog, the 120s unhealthy give-up window and the 60s backoff reset.
/// "t=" in comments is fake time in seconds. Jitter is pinned to 0 by the harness.
///
/// No test for a named event with no data and the watchdog: `SSEParser` never produces an
/// event without data (`SSEParserTests.testBlockWithNoDataLineProducesNoEvent`), so this can't
/// happen.
final class StreamConnectionTimingTests: XCTestCase {

    // MARK: - Watchdog (70s of silence)

    /// After the stream opens, 70s of silence makes the watchdog reconnect.
    func testWatchdogReconnectsAfter70SecondsOfSilence() throws {
        let h = StreamConnectionHarness()
        h.start()
        try XCTUnwrap(h.latest).simulateOpen()

        h.advance(69_999)
        XCTAssertEqual(h.sources.count, 1)
        h.advance(1)  // the watchdog fires and schedules a retry
        h.advance(1_000)
        XCTAssertEqual(h.sources.count, 2)
        XCTAssertEqual(h.errors, [])
    }

    /// Received bytes alone reset the watchdog.
    func testReceivedBytesResetTheWatchdog() throws {
        let h = StreamConnectionHarness()
        h.start()
        try XCTUnwrap(h.latest).simulateOpen()

        h.advance(60_000)
        try XCTUnwrap(h.latest).simulateBytes()
        h.advance(60_000)
        XCTAssertEqual(h.sources.count, 1, "the first watchdog would have fired at t=70")

        h.advance(10_000 + 1_000)  // the reset watchdog fires at t=130, the retry at t=131
        XCTAssertEqual(h.sources.count, 2, "the watchdog was re-armed, not just cancelled")
    }

    /// A named event with data marks the connection healthy, which resets the watchdog.
    func testNamedEventResetsTheWatchdog() throws {
        let h = StreamConnectionHarness()
        h.start()
        try XCTUnwrap(h.latest).simulateOpen()

        h.advance(60_000)
        try XCTUnwrap(h.latest).emit("put", "{}")
        h.advance(60_000)
        XCTAssertEqual(h.sources.count, 1)
    }

    /// An unnamed message resets the watchdog even with no `onUnhandledMessage`.
    func testUnnamedMessageResetsTheWatchdogEvenWithoutOnUnhandledMessage() throws {
        let h = StreamConnectionHarness(recordsUnhandledMessages: false)
        h.start()
        try XCTUnwrap(h.latest).simulateOpen()

        h.advance(60_000)
        try XCTUnwrap(h.latest).simulateMessage("{}")
        h.advance(60_000)
        XCTAssertEqual(h.sources.count, 1)
    }

    /// With no event names and no `onUnhandledMessage`, heartbeat bytes alone keep the connection alive.
    func testHeartbeatBytesAloneKeepTheConnectionAlive() throws {
        let h = StreamConnectionHarness(eventNames: [], recordsUnhandledMessages: false)
        h.start()
        try XCTUnwrap(h.latest).simulateOpen()

        for _ in 0..<5 {
            h.advance(60_000)
            try XCTUnwrap(h.latest).simulateBytes()
        }

        XCTAssertEqual(h.sources.count, 1)
        XCTAssertEqual(h.errors, [])
    }

    /// After 10 healthy minutes, a single drop reconnects and does NOT give up.
    func testSingleDropAfterTenHealthyMinutesReconnects() throws {
        let h = StreamConnectionHarness()
        h.start()
        try XCTUnwrap(h.latest).simulateOpen()
        for _ in 0..<10 {
            h.advance(60_000)
            try XCTUnwrap(h.latest).simulateBytes()
        }
        XCTAssertEqual(h.sources.count, 1)

        try XCTUnwrap(h.latest).simulateError()
        h.advance(1_000)
        XCTAssertEqual(h.sources.count, 2)
        XCTAssertEqual(h.errors, [])
    }

    // MARK: - Unhealthy window (give up after more than 120s)

    /// Unhealthy for over 120s with no events in between gives up, non-terminal.
    func testUnhealthyForOver120SecondsGivesUpOnce() throws {
        let h = StreamConnectionHarness()
        h.start()
        try XCTUnwrap(h.latest).simulateOpen()
        try XCTUnwrap(h.latest).simulateError()  // t=0: unhealthy

        for delaySeconds: Int64 in [1, 2, 4, 8, 16, 30, 30] {
            h.advance(delaySeconds * 1_000)
            XCTAssertEqual(h.errors, [])
            try XCTUnwrap(h.latest).simulateError()
        }
        h.advance(30_000)  // t=121
        try XCTUnwrap(h.latest).simulateError()
        XCTAssertEqual(h.errors, [StreamConnectionErrorInfo(terminal: false)])

        let sourcesAtGiveUp = h.sources.count
        h.advance(300_000)
        XCTAssertEqual(h.sources.count, sourcesAtGiveUp, "nothing is retried after giving up")
        XCTAssertEqual(h.errors.count, 1)
    }

    /// Repeated recoverable errors before open give up once the unhealthy window elapses.
    func testRepeatedPreOpenErrorsGiveUpAfter120Seconds() throws {
        let h = StreamConnectionHarness()
        h.start()
        try XCTUnwrap(h.latest).simulateError(status: 500)  // t=0: unhealthy

        for delaySeconds: Int64 in [1, 2, 4, 8, 16, 30, 30] {
            h.advance(delaySeconds * 1_000)
            XCTAssertEqual(h.errors, [])
            try XCTUnwrap(h.latest).simulateError(status: 500)
        }
        h.advance(30_000)  // t=121
        try XCTUnwrap(h.latest).simulateError(status: 500)
        XCTAssertEqual(h.errors, [StreamConnectionErrorInfo(terminal: false)])
    }

    /// An event received between drops restarts the unhealthy window.
    func testDataBetweenDropsRestartsTheUnhealthyWindow() throws {
        let h = StreamConnectionHarness()
        h.start()
        try XCTUnwrap(h.latest).simulateOpen()
        try XCTUnwrap(h.latest).simulateError()  // t=0: unhealthy
        h.advance(1_000)
        try XCTUnwrap(h.latest).simulateError()
        h.advance(2_000)  // t=3

        try XCTUnwrap(h.latest).simulateBytes()  // healthy again
        try XCTUnwrap(h.latest).simulateError()  // t=3: a new window starts here

        for delaySeconds: Int64 in [4, 8, 16, 30, 30, 30] {
            h.advance(delaySeconds * 1_000)
            try XCTUnwrap(h.latest).simulateError()
        }
        XCTAssertEqual(h.errors, [], "t=121 is only 118s into the new window")

        h.advance(30_000)  // t=151: 148s into the new window
        try XCTUnwrap(h.latest).simulateError()
        XCTAssertEqual(h.errors, [StreamConnectionErrorInfo(terminal: false)])
    }

    /// A connect that hangs without ever opening gives up once the window elapses.
    func testConnectThatNeverOpensGivesUpAfterTheWindow() {
        let h = StreamConnectionHarness()
        h.start()

        h.advance(70_000)  // t=70: the watchdog doubles as the connect timeout
        h.advance(1_000)
        XCTAssertEqual(h.sources.count, 2)

        h.advance(70_000)  // t=141: 71s unhealthy, still retries
        h.advance(2_000)
        XCTAssertEqual(h.sources.count, 3)
        XCTAssertEqual(h.errors, [])

        h.advance(70_000)  // t=213: 143s unhealthy, gives up
        XCTAssertEqual(h.errors, [StreamConnectionErrorInfo(terminal: false)])
        XCTAssertEqual(h.sources.count, 3)
    }

    /// An external `reconnect()` must NOT reset the unhealthy give-up window.
    func testExternalReconnectDoesNotResetTheUnhealthyWindow() throws {
        let h = StreamConnectionHarness()
        h.start()

        try XCTUnwrap(h.latest).simulateError(status: 500)  // t=0: unhealthy
        h.connection.reconnect()

        h.advance(60_000)  // t=60
        try XCTUnwrap(h.latest).simulateError(status: 500)
        h.connection.reconnect()

        h.advance(60_000)  // t=120: exactly 120s is not more than 120s
        try XCTUnwrap(h.latest).simulateError(status: 500)
        XCTAssertEqual(h.errors, [])
        h.connection.reconnect()

        h.advance(60_000)  // t=180
        try XCTUnwrap(h.latest).simulateError(status: 500)
        XCTAssertEqual(h.errors, [StreamConnectionErrorInfo(terminal: false)])
    }

    /// A reconnect whose connection recovers and delivers data clears the unhealthy window.
    func testRecoveredReconnectClearsTheUnhealthyWindow() throws {
        let h = StreamConnectionHarness()
        h.start()
        try XCTUnwrap(h.latest).simulateError(status: 500)  // t=0: unhealthy
        h.connection.reconnect()
        h.advance(60_000)  // t=60
        try XCTUnwrap(h.latest).simulateError(status: 500)
        h.connection.reconnect()

        h.advance(60_000)  // t=120: this connection opens and delivers bytes
        try XCTUnwrap(h.latest).simulateOpen()
        try XCTUnwrap(h.latest).simulateBytes()
        XCTAssertEqual(h.openCount, 1)

        for _ in 0..<4 {
            h.advance(60_000)
            try XCTUnwrap(h.latest).simulateBytes()
        }

        XCTAssertEqual(h.errors, [])
        XCTAssertEqual(h.sources.count, 3)
        XCTAssertFalse(try XCTUnwrap(h.latest).closed)

        // Without a drop, a window that was never cleared can't show. At t=360 a single drop
        // must reconnect, not give up for "360s unhealthy since t=0".
        try XCTUnwrap(h.latest).simulateError()
        h.advance(1_000)
        XCTAssertEqual(h.errors, [])
        XCTAssertEqual(h.sources.count, 4)
    }

    // MARK: - Backoff reset (open for 60s)

    /// A connection that stays open 60s resets the delay before its next drop.
    func testStableConnectionResetsBackoffBeforeTheNextDrop() throws {
        let h = StreamConnectionHarness()
        h.start()
        try XCTUnwrap(h.latest).simulateOpen()
        try XCTUnwrap(h.latest).simulateError()
        h.advance(1_000)
        try XCTUnwrap(h.latest).simulateOpen()
        try XCTUnwrap(h.latest).simulateError()
        h.advance(2_000)
        XCTAssertEqual(h.sources.count, 3)

        try XCTUnwrap(h.latest).simulateOpen()
        h.advance(60_000)
        try XCTUnwrap(h.latest).simulateError()

        h.advance(999)
        XCTAssertEqual(h.sources.count, 3)
        h.advance(1)
        XCTAssertEqual(h.sources.count, 4, "retry after 1s, not 4s")
    }

    /// A connection that drops before 60s keeps escalating (flapping protection).
    func testDropBefore60SecondsKeepsEscalating() throws {
        let h = StreamConnectionHarness()
        h.start()
        try XCTUnwrap(h.latest).simulateOpen()
        try XCTUnwrap(h.latest).simulateError()
        h.advance(1_000)

        try XCTUnwrap(h.latest).simulateOpen()
        h.advance(5_000)
        try XCTUnwrap(h.latest).simulateError()

        h.advance(1_999)
        XCTAssertEqual(h.sources.count, 2)
        h.advance(1)
        XCTAssertEqual(h.sources.count, 3, "still 2s: a 5s connection is not stable")
    }

    /// In the test above the next open replaces the reset timer before it is due, so
    /// it can't show whether a drop cancels it. Here the connection drops at t=59 and the retry
    /// fails before opening: the dead connection's timer must not reset the backoff at t=60.
    func testDropJustBefore60SecondsDoesNotResetBackoffLater() throws {
        let h = StreamConnectionHarness()
        h.start()
        try XCTUnwrap(h.latest).simulateOpen()  // t=0
        h.advance(59_000)
        try XCTUnwrap(h.latest).simulateError()  // t=59: retry in 1s
        h.advance(1_000)  // t=60: the retry opens, and the dropped connection's reset would be due
        XCTAssertEqual(h.sources.count, 2)

        try XCTUnwrap(h.latest).simulateError()
        h.advance(1_999)
        XCTAssertEqual(h.sources.count, 2)
        h.advance(1)
        XCTAssertEqual(h.sources.count, 3, "still 2s: the dropped connection never became stable")
    }
}
