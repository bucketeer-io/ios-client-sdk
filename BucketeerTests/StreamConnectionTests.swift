import XCTest
@testable import Bucketeer

/// Lifecycle, error sorting and event delivery of `StreamConnection`. Timing rules (watchdog,
/// give-up window, backoff reset) are in `StreamConnectionTimingTests`.
///
/// No test for a `terminal` flag on an error: `EventSource.onError` has none; the HTTP status is
/// the only terminal signal.
final class StreamConnectionTests: XCTestCase {

    func testStartOpensOneEventSourceWithTheBuiltRequest() throws {
        let h = StreamConnectionHarness()
        h.start()

        XCTAssertEqual(h.sources.count, 1)
        let source = try XCTUnwrap(h.latest)
        XCTAssertEqual(source.openCount, 1)
        XCTAssertEqual(source.openedRequest?.url?.absoluteString, "https://example.test/sse?attempt=1")
        XCTAssertEqual(h.builderCallCount, 1)
        XCTAssertEqual(h.errors, [])
    }

    /// `requestBuilder` runs again on every connect and reconnect, so each attempt sends the
    /// latest user attributes and cache state.
    func testRequestBuilderRunsAgainOnEveryConnect() throws {
        let h = StreamConnectionHarness()
        h.start()
        try XCTUnwrap(h.latest).simulateError()
        h.advance(1_000)

        XCTAssertEqual(h.sources.count, 2)
        XCTAssertEqual(try XCTUnwrap(h.latest).openedRequest?.url?.query, "attempt=2")

        h.connection.reconnect()
        XCTAssertEqual(try XCTUnwrap(h.latest).openedRequest?.url?.query, "attempt=3")
        XCTAssertEqual(h.builderCallCount, 3)
    }

    /// Open, then events: `onOpen` is called and the data reaches its handlers.
    func testOpenThenEventsReachTheirHandlers() throws {
        let h = StreamConnectionHarness()
        h.start()
        let source = try XCTUnwrap(h.latest)

        source.simulateOpen()
        XCTAssertEqual(h.openCount, 1)

        source.emit("put", "{\"p\":1}")
        source.emit("patch", "{\"q\":2}")
        source.emit("error", "{\"code\":\"x\"}")
        XCTAssertEqual(h.received, [
            SSEEvent(name: "put", data: "{\"p\":1}"),
            SSEEvent(name: "patch", data: "{\"q\":2}"),
            SSEEvent(name: "error", data: "{\"code\":\"x\"}")
        ])

        source.simulateMessage("{\"a\":1}")
        XCTAssertEqual(h.unhandled, ["{\"a\":1}"])
    }

    /// A "message" key in the events map is ignored. That channel belongs to the connection itself.
    func testMessageKeyInEventsMapIsIgnored() throws {
        let h = StreamConnectionHarness(eventNames: ["put", "patch", "error", "message"])
        h.start()
        let source = try XCTUnwrap(h.latest)

        XCTAssertEqual(Set(source.listeners.keys), ["put", "patch", "error"])

        source.simulateMessage("{\"a\":1}")
        XCTAssertEqual(h.unhandled, ["{\"a\":1}"])
        XCTAssertEqual(h.received, [])
    }

    /// An error with a terminal status gives up as terminal, with no retry.
    func testTerminalStatusGivesUpWithoutRetry() throws {
        for status in [401, 403] {
            let h = StreamConnectionHarness()
            h.start()
            try XCTUnwrap(h.latest).simulateError(status: status)

            XCTAssertEqual(h.errors, [StreamConnectionErrorInfo(terminal: true)], "status \(status)")
            XCTAssertTrue(h.sources[0].closed, "status \(status)")

            h.advance(300_000)
            XCTAssertEqual(h.sources.count, 1, "status \(status)")
        }
    }

    /// An error with a non-recoverable status gives up (non-terminal) at once, with no backoff retry.
    func testNonRecoverableStatusGivesUpImmediatelyWithoutRetry() throws {
        for status in [400, 413, 422] {
            let h = StreamConnectionHarness()
            h.start()
            try XCTUnwrap(h.latest).simulateError(status: status)

            XCTAssertEqual(h.errors, [StreamConnectionErrorInfo(terminal: false)], "status \(status)")
            XCTAssertTrue(h.sources[0].closed, "status \(status)")

            h.advance(300_000)
            XCTAssertEqual(h.sources.count, 1, "status \(status)")
        }
    }

    /// An error before the first open with a recoverable status retries with backoff.
    func testRecoverableErrorBeforeOpenRetriesWithBackoff() throws {
        for status in [nil, 408, 429, 499, 500, 503] as [Int?] {
            let h = StreamConnectionHarness()
            h.start()
            try XCTUnwrap(h.latest).simulateError(status: status)
            XCTAssertEqual(h.errors, [], "status \(String(describing: status))")

            h.advance(999)
            XCTAssertEqual(h.sources.count, 1, "status \(String(describing: status))")
            h.advance(1)
            XCTAssertEqual(h.sources.count, 2, "status \(String(describing: status))")
        }
    }

    /// A transient error after open heals itself with backoff; `onError` is NOT called.
    func testTransientErrorAfterOpenSelfHeals() throws {
        let h = StreamConnectionHarness()
        h.start()
        try XCTUnwrap(h.latest).simulateOpen()
        try XCTUnwrap(h.latest).simulateError()

        h.advance(999)
        XCTAssertEqual(h.sources.count, 1)
        h.advance(1)
        XCTAssertEqual(h.sources.count, 2)
        XCTAssertEqual(h.errors, [])
    }

    /// `reconnect()` while a backoff retry is pending opens exactly one new connection.
    func testReconnectWhileRetryIsPendingOpensExactlyOneConnection() throws {
        let h = StreamConnectionHarness()
        h.start()
        try XCTUnwrap(h.latest).simulateOpen()
        try XCTUnwrap(h.latest).simulateError()
        XCTAssertEqual(h.sources.count, 1)
        XCTAssertTrue(h.sources[0].closed)

        h.connection.reconnect()
        XCTAssertEqual(h.sources.count, 2)

        h.advance(10_000)
        XCTAssertEqual(h.sources.count, 2, "the cancelled retry must not open a third connection")
        XCTAssertFalse(h.sources[1].closed)
    }

    /// `reconnect()` resets the backoff.
    func testReconnectResetsBackoff() throws {
        let h = StreamConnectionHarness()
        h.start()
        try XCTUnwrap(h.latest).simulateError()
        h.advance(1_000)
        try XCTUnwrap(h.latest).simulateError()
        h.advance(2_000)
        try XCTUnwrap(h.latest).simulateError()  // the next retry would wait 4s
        XCTAssertEqual(h.sources.count, 3)

        h.connection.reconnect()
        XCTAssertEqual(h.sources.count, 4)
        try XCTUnwrap(h.latest).simulateError()

        h.advance(999)
        XCTAssertEqual(h.sources.count, 4)
        h.advance(1)
        XCTAssertEqual(h.sources.count, 5, "retry after 1s, not 4s")
    }

    /// `reconnect()` does nothing unless the connection is active: before `start()` or after `stop()`.
    func testReconnectIsIgnoredBeforeStartAndAfterStop() {
        let h = StreamConnectionHarness()
        h.connection.reconnect()
        XCTAssertEqual(h.sources.count, 0)

        h.start()
        h.connection.stop()
        h.connection.reconnect()
        XCTAssertEqual(h.sources.count, 1)
    }

    /// Events and errors from a stale (replaced) event source are ignored.
    func testCallbacksFromAReplacedEventSourceAreIgnored() throws {
        let h = StreamConnectionHarness()
        h.start()
        let stale = try XCTUnwrap(h.latest)
        stale.simulateOpen()
        stale.simulateError()
        h.advance(1_000)
        let current = try XCTUnwrap(h.latest)
        XCTAssertEqual(h.sources.count, 2)
        current.simulateOpen()
        XCTAssertEqual(h.openCount, 2)

        stale.simulateOpen()
        stale.emit("put", "late")
        stale.simulateMessage("late")
        stale.simulateBytes()
        stale.simulateError(status: 401)

        XCTAssertEqual(h.openCount, 2)
        XCTAssertEqual(h.received, [])
        XCTAssertEqual(h.unhandled, [])
        XCTAssertEqual(h.errors, [])
        XCTAssertFalse(current.closed)
    }

    /// `stop()` cancels the timers, closes the event source, and ignores later errors.
    func testStopCancelsTimersClosesEventSourceAndIgnoresLateErrors() throws {
        let h = StreamConnectionHarness()
        h.start()
        try XCTUnwrap(h.latest).simulateOpen()
        try XCTUnwrap(h.latest).simulateError()  // a retry is now pending

        h.connection.stop()
        XCTAssertTrue(h.sources[0].closed)

        h.advance(300_000)
        XCTAssertEqual(h.sources.count, 1, "neither the retry nor the watchdog may fire after stop()")

        h.sources[0].simulateError()
        XCTAssertEqual(h.errors, [])
    }

    /// A request build that throws is reported to `onError` (non-terminal) instead of crashing.
    /// `openConnection()` also runs from a timer callback, so the retry path (b) must be safe too.
    func testThrowingRequestBuilderReportsNonTerminalErrorWithoutCrashing() throws {
        // (a) The first build throws.
        let alwaysThrows = StreamConnectionHarness(requestBuilder: { _ in
            throw StreamConnectionHarness.TestError()
        })
        alwaysThrows.start()
        XCTAssertEqual(alwaysThrows.sources.count, 0)
        XCTAssertEqual(alwaysThrows.errors, [StreamConnectionErrorInfo(terminal: false)])
        XCTAssertNotNil(alwaysThrows.logger.error)

        // (b) The build throws on the timer-driven retry.
        let throwsOnRetry = StreamConnectionHarness(requestBuilder: { attempt in
            guard attempt == 1 else { throw StreamConnectionHarness.TestError() }
            return URLRequest(url: URL(string: "https://example.test/sse")!)
        })
        throwsOnRetry.start()
        try XCTUnwrap(throwsOnRetry.latest).simulateError()
        throwsOnRetry.advance(1_000)

        XCTAssertEqual(throwsOnRetry.errors, [StreamConnectionErrorInfo(terminal: false)])
        XCTAssertEqual(throwsOnRetry.sources.count, 1)
        XCTAssertEqual(throwsOnRetry.scheduler.pendingCount, 0, "nothing left scheduled after giving up")
    }
}
