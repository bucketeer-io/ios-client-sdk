import XCTest
@testable import Bucketeer

/// `URLSessionEventSource` against a scripted server (`MockURLProtocol`), ported from the JS
/// `FetchEventSource.spec.ts` where it applies.
///
/// JS tests not ported:
/// - "missing response.body is terminal", "a body without getReader" and "the injected fetch is
///   called receiver-free": JS runtime specifics with no URLSession equivalent.
/// - "event: patch", "multi-line data", "CRLF framing", "CRLF split", "blank-line split" and
///   "stream ending mid multi-byte character": parsing, already covered by `SSEParserTests`.
final class URLSessionEventSourceTests: XCTestCase {
    private var harnesses: [URLSessionEventSourceHarness] = []

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        harnesses.forEach { $0.close() }  // an open session keeps its event source alive
        harnesses = []
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func makeHarness(_ steps: [MockURLProtocol.Step], listeners: [String] = []) -> URLSessionEventSourceHarness {
        let harness = URLSessionEventSourceHarness(steps: steps, listenerNames: listeners)
        harnesses.append(harness)
        return harness
    }

    /// Opens, then waits until the attempt ended (the first `onError`).
    private func run(_ steps: [MockURLProtocol.Step], listeners: [String] = []) -> URLSessionEventSourceHarness {
        let harness = makeHarness(steps, listeners: listeners)
        harness.open()
        wait(for: [harness.ended], timeout: 2)
        return harness
    }

    // MARK: - Dispatching events

    /// JS: "200 + data block: onopen fires and onmessage receives the data".
    func testSuccessfulResponseOpensAndOnMessageReceivesData() {
        let h = run([.response(status: 200), .data("data: {\"a\":1}\n\n"), .finish])

        XCTAssertEqual(h.read { $0.openCount }, 1)
        XCTAssertEqual(h.read { $0.log.first }, "open")
        XCTAssertEqual(h.read { $0.messages }, [SSEEvent(name: "message", data: "{\"a\":1}")])
    }

    /// JS: "named event block goes to its listener, not onmessage".
    func testNamedEventGoesToItsListenerNotOnMessage() {
        let h = run([.response(status: 200), .data("event: put\ndata: {\"b\":2}\n\n"), .finish], listeners: ["put"])

        XCTAssertEqual(h.read { $0.received }, [SSEEvent(name: "put", data: "{\"b\":2}")])
        XCTAssertEqual(h.read { $0.messages }, [])
    }

    /// JS: "a named event with no registered listener is dropped, not delivered to onmessage".
    func testNamedEventWithNoListenerIsDropped() {
        let h = run([.response(status: 200), .data("event: ping\ndata: {\"c\":3}\n\n"), .finish])

        XCTAssertEqual(h.read { $0.messages }, [])
    }

    /// JS: "an explicit \"event: message\" block reaches onmessage".
    func testExplicitMessageEventReachesOnMessage() {
        let h = run([.response(status: 200), .data("event: message\ndata: {\"m\":1}\n\n"), .finish])

        XCTAssertEqual(h.read { $0.messages }, [SSEEvent(name: "message", data: "{\"m\":1}")])
    }

    /// JS: "an empty \"event:\" line falls back to the default message type".
    func testEmptyEventLineReachesOnMessage() {
        let h = run([.response(status: 200), .data("event:\ndata: {\"m\":2}\n\n"), .finish])

        XCTAssertEqual(h.read { $0.messages }, [SSEEvent(name: "message", data: "{\"m\":2}")])
    }

    /// JS: "SSE comment fires a liveness tick but dispatches no data". `:` is the backend's
    /// real heartbeat.
    func testCommentOnlyStreamSignalsBytesButNoEvent() {
        let h = run([.response(status: 200), .data(":\n\n"), .finish], listeners: ["put"])

        XCTAssertGreaterThanOrEqual(h.read { $0.bytesCount }, 1)
        XCTAssertEqual(h.read { $0.messages }, [])
        XCTAssertEqual(h.read { $0.received }, [])
    }

    /// JS: "a payload delivered in many small chunks ... parses identically". The full matrix
    /// is in `SSEParserTests`.
    func testEventSplitAcrossChunksArrivesWhole() {
        let h = run([.response(status: 200), .data("event: pu"), .data("t\ndata: {\"a\""), .data(":1}\n\n"), .finish],
                    listeners: ["put"])

        XCTAssertEqual(h.read { $0.received }, [SSEEvent(name: "put", data: "{\"a\":1}")])
    }

    /// iOS only. Proves that a named event with no data can't reach `StreamConnection`, which is
    /// why the JS test "a named event with no data does not reset the watchdog" isn't ported.
    func testNamedEventWithNoDataNeverReachesItsListener() {
        let h = run([.response(status: 200), .data("event: error\n\n"), .data("event: put\ndata: {\"a\":1}\n\n"), .finish],
                    listeners: ["error", "put"])

        XCTAssertGreaterThanOrEqual(h.read { $0.bytesCount }, 1)
        XCTAssertEqual(h.read { $0.received }, [SSEEvent(name: "put", data: "{\"a\":1}")],
                       "the dataless error block delivered nothing")
    }

    // MARK: - Errors and closing

    /// JS: "non-200 response reports onerror with the status". iOS also checks "only once": the
    /// `.cancel` answer to a bad status makes URLSession report a second, cancelled completion.
    func testErrorStatusIsReportedOnceAndNeverOpens() {
        for status in [500, 401] {
            let h = makeHarness([.response(status: status)])
            let secondError = XCTestExpectation(description: "a second onError")
            secondError.isInverted = true
            h.open()
            wait(for: [h.ended], timeout: 2)
            h.queue.asyncAfter(deadline: .now() + .milliseconds(250)) {
                if h.errors.count > 1 { secondError.fulfill() }
            }
            wait(for: [secondError], timeout: 0.4)

            XCTAssertEqual(h.read { $0.errors }, [status], "status \(status)")
            XCTAssertEqual(h.read { $0.openCount }, 0, "status \(status)")
        }
    }

    /// JS: "a stream that errors mid-read reports onerror"; "network error (fetch rejects)".
    func testNetworkFailureAfterDataDeliversEventThenNilStatus() {
        let h = run([.response(status: 200), .data("event: put\ndata: {\"a\":1}\n\n"), .wait(milliseconds: 100),
                     .fail(URLError(.networkConnectionLost))],
                    listeners: ["put"])

        XCTAssertEqual(h.read { $0.received }, [SSEEvent(name: "put", data: "{\"a\":1}")])
        XCTAssertEqual(h.read { $0.errors }, [nil])
    }

    /// JS: "Natural end-of-stream reports a recoverable (empty) error".
    func testServerClosingTheStreamReportsNilStatus() {
        let h = run([.response(status: 200), .data("data: x\n\n"), .finish])

        XCTAssertEqual(h.read { $0.errors }, [nil])
    }

    /// JS: "close() aborts the request and swallows the AbortError".
    func testCloseSuppressesTheCancellationError() {
        let h = makeHarness([.response(status: 200)])  // holds the stream open
        let noError = XCTestExpectation(description: "onError after close")
        noError.isInverted = true
        h.open()
        wait(for: [h.opened], timeout: 2)

        h.close()
        h.queue.asyncAfter(deadline: .now() + .milliseconds(250)) {
            if !h.errors.isEmpty { noError.fulfill() }
        }
        wait(for: [noError], timeout: 0.4)
        XCTAssertEqual(h.read { $0.errors }, [])
    }

    /// iOS only. Proves `open()` never calls back before it returns, even when the request fails
    /// at once. That is why `StreamConnection` can arm its watchdog after `open()`, as JS does.
    func testOpenNeverReportsAnErrorBeforeReturning() {
        let h = makeHarness([.fail(URLError(.cannotConnectToHost))])
        var errorsWhenOpenReturned = -1
        h.queue.sync {
            h.source?.open(request: URLSessionEventSourceHarness.request())
            errorsWhenOpenReturned = h.errors.count
        }
        wait(for: [h.ended], timeout: 2)

        XCTAssertEqual(errorsWhenOpenReturned, 0)
        XCTAssertEqual(h.read { $0.errors }, [nil])
    }

    // MARK: - Request, configuration, threading, memory

    /// JS: "default headers are sent and caller headers win over them". Unlike JS, the method
    /// is not defaulted to POST: a `URLRequest` starts as GET, so "not set" can't be detected.
    func testDefaultHeadersAreSentAndCallerHeadersWin() throws {
        var request = URLSessionEventSourceHarness.request()
        request.httpMethod = "POST"
        request.setValue("api-key-value", forHTTPHeaderField: "Authorization")
        request.setValue("application/custom", forHTTPHeaderField: "Accept")
        request.httpBody = Data("{\"tag\":\"t\"}".utf8)
        let custom = makeHarness([.response(status: 200), .finish])
        custom.open(request)
        wait(for: [custom.ended], timeout: 2)

        let sent = try XCTUnwrap(MockURLProtocol.lastRequest)
        XCTAssertEqual(sent.httpMethod, "POST")
        XCTAssertEqual(sent.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(sent.value(forHTTPHeaderField: "Accept"), "application/custom")
        XCTAssertEqual(sent.value(forHTTPHeaderField: "Authorization"), "api-key-value")
        XCTAssertEqual(MockURLProtocol.lastRequestBody, Data("{\"tag\":\"t\"}".utf8))

        let plain = makeHarness([.response(status: 200), .finish])
        plain.open()
        wait(for: [plain.ended], timeout: 2)
        XCTAssertEqual(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Accept"), "text/event-stream")
    }

    /// iOS only. URLSession's default 60s idle timeout would fire before the 70s watchdog.
    func testPrepareRequestSetsTheStreamTimeout() {
        let request = URLSessionEventSourceHarness.request()
        XCTAssertEqual(request.timeoutInterval, 60)

        XCTAssertEqual(URLSessionEventSource.prepareRequest(request).timeoutInterval, 90)
    }

    /// iOS only. All connection state lives on the serial SDK queue, so every callback must
    /// arrive there.
    func testCallbacksRunOnTheEventSourceQueue() {
        let h = run([.response(status: 200), .data("event: put\ndata: {}\n\ndata: {}\n\n"), .finish], listeners: ["put"])

        XCTAssertGreaterThanOrEqual(h.read { $0.log.count }, 5, "open, bytes, put, message, error")
        XCTAssertEqual(h.read { $0.offQueueCallbacks }, 0)
    }

    /// iOS only. A `URLSession` holds its delegate until it is invalidated, so without
    /// `invalidateAndCancel()` in `close()` the event source would never be freed.
    func testEventSourceIsReleasedAfterClose() {
        let h = makeHarness([.response(status: 200)])
        weak var weakSource: URLSessionEventSource?
        // `queue.sync` runs on this test's thread, so the URLSession setup in open() leaves an
        // autoreleased reference in the test's own pool, which drains only when the test ends.
        // In production open() runs in a GCD block, whose pool drains after each block.
        autoreleasepool {
            weakSource = h.source
            h.open()
        }
        wait(for: [h.opened], timeout: 2)

        autoreleasepool {
            h.close()
            h.releaseSource()
        }
        let released = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in weakSource == nil }, object: nil)
        wait(for: [released], timeout: 2)
    }

    /// iOS only.
    func testDefaultConfiguration() {
        let configuration = URLSessionEventSource.makeConfiguration()

        XCTAssertEqual(configuration.timeoutIntervalForRequest, 90)
        XCTAssertEqual(configuration.requestCachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertFalse(configuration.waitsForConnectivity)
    }
}
