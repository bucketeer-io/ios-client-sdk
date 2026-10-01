import XCTest
@testable import Bucketeer

/// Lifecycle, error sorting and event delivery of `StreamConnection`, ported from the JS
/// `StreamConnection.spec.ts` ("health model" suite). Timing rules (watchdog, give-up window,
/// backoff reset) are in `StreamConnectionTimingTests`.
///
/// JS tests not ported:
/// - "error with terminal: true from the EventSource": iOS has no `terminal` flag on
///   `EventSource.onError`; the HTTP status is the only terminal signal.
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

    /// JS: `requestBuilder` is "re-invoked on every (re)connect", so each attempt sends the
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

    /// JS: "open then event: onOpen called, data dispatched".
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

    /// JS source: "A 'message' key is ignored". That channel belongs to the connection itself.
    func testMessageKeyInEventsMapIsIgnored() throws {
        let h = StreamConnectionHarness(eventNames: ["put", "patch", "error", "message"])
        h.start()
        let source = try XCTUnwrap(h.latest)

        XCTAssertEqual(Set(source.listeners.keys), ["put", "patch", "error"])

        source.simulateMessage("{\"a\":1}")
        XCTAssertEqual(h.unhandled, ["{\"a\":1}"])
        XCTAssertEqual(h.received, [])
    }

    /// JS: "error with status %i gives up terminal, no retry".
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

    /// JS: "error with status %i gives up non-terminal immediately, no backoff retry".
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

    /// JS: "error before first open with a recoverable status retries with backoff".
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

    /// JS: "transient error after open self-heals with backoff, onError NOT called".
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

    /// JS: "reconnect() while a backoff retry is pending produces exactly one new connection".
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

    /// JS source: `reconnect()` calls `this.backoff.reset()`.
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

    /// JS source: `reconnect()` starts with `if (!this.active) return`.
    func testReconnectIsIgnoredBeforeStartAndAfterStop() {
        let h = StreamConnectionHarness()
        h.connection.reconnect()
        XCTAssertEqual(h.sources.count, 0)

        h.start()
        h.connection.stop()
        h.connection.reconnect()
        XCTAssertEqual(h.sources.count, 1)
    }

    /// JS: "events and errors from a stale (replaced) EventSource instance are ignored".
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

    /// JS: "stop() clears timers, closes the EventSource, and ignores later errors".
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

    /// JS: "a synchronously-throwing eventSource constructor is routed to onError instead of
    /// crashing". JS source comment: `openConnection()` also runs from a timer callback, so
    /// the retry path (b) must be safe too.
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
