import Foundation
import XCTest

/// Tests for the proxy server the streaming E2E tests run through (`RecordingProxy`).
///
/// They check the proxy itself, not the SDK, so they need no backend and no keys: the proxy
/// forwards to `MockURLProtocol`, a scripted fake backend, and a plain `URLSession` plays the
/// SDK's side over real loopback HTTP.
final class RecordingProxyTests: XCTestCase {
    private let upstream = URL(string: "https://backend.test/v1")!
    private var proxy: RecordingProxy!
    private var client: ProxyTestClient!

    override func setUpWithError() throws {
        try super.setUpWithError()
        MockURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        proxy = try RecordingProxy(upstream: upstream, configuration: configuration)
        client = ProxyTestClient()
    }

    override func tearDownWithError() throws {
        client.invalidate()
        proxy.stop()
        MockURLProtocol.reset()
        try super.tearDownWithError()
    }

    // Also the check that iOS allows plain http to 127.0.0.1 from the test bundle: if it did
    // not, this request would fail before reaching the proxy.
    func testPlainHttpToLoopbackReachesTheBackend() {
        MockURLProtocol.steps = [.response(status: 200), .data("ok"), .finish]

        let exchange = client.send(URLRequest(url: proxy.url.appendingPathComponent("get_evaluations")))
        wait(for: [exchange.completed], timeout: 5)

        XCTAssertNil(exchange.error)
        XCTAssertEqual(exchange.status, 200)
        XCTAssertEqual(exchange.body, "ok")
        XCTAssertEqual(MockURLProtocol.lastRequest?.url?.absoluteString, "https://backend.test/v1/get_evaluations")
    }

    func testStreamPiecesArriveOneAtATime() {
        MockURLProtocol.steps = [
            .response(status: 200),
            .data("a"),
            .wait(milliseconds: 3_000),
            .data("b"),
            .finish
        ]

        let exchange = client.send(URLRequest(url: proxy.url.appendingPathComponent("stream")))

        // "a" must reach the client while "b" is still 3s away, not when the reply ends.
        wait(for: [exchange.firstPiece], timeout: 2)
        XCTAssertEqual(exchange.body, "a")
        wait(for: [exchange.completed], timeout: 6)
        XCTAssertEqual(exchange.body, "ab")
    }

    func testForwardsMethodPathAndBodyButNotConnectionHeaders() {
        MockURLProtocol.steps = [.response(status: 200), .finish]
        var request = URLRequest(url: proxy.url.appendingPathComponent("get_evaluations"))
        request.httpMethod = "POST"
        request.httpBody = Data(#"{"tag":"ios"}"#.utf8)
        request.setValue("api-key", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let exchange = client.send(request)
        wait(for: [exchange.completed], timeout: 5)

        let forwarded = MockURLProtocol.lastRequest
        XCTAssertEqual(forwarded?.httpMethod, "POST")
        XCTAssertEqual(forwarded?.url?.absoluteString, "https://backend.test/v1/get_evaluations")
        XCTAssertEqual(MockURLProtocol.lastRequestBody, Data(#"{"tag":"ios"}"#.utf8))
        XCTAssertEqual(forwarded?.value(forHTTPHeaderField: "Authorization"), "api-key")
        XCTAssertEqual(forwarded?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        // The client's connection headers describe its hop to the proxy, not the hop to the
        // backend. Forwarding Host would send the backend "127.0.0.1:<port>". Content-Length is
        // not checked: the forwarding session always sets it from the body.
        for name in ["Host", "Connection", "Transfer-Encoding"] {
            XCTAssertNil(forwarded?.value(forHTTPHeaderField: name), "\(name) was forwarded")
        }
    }

    func testRecordsPathAndStatusAndPassesAnErrorStatusBack() {
        MockURLProtocol.steps = [.response(status: 401), .finish]

        let exchange = client.send(URLRequest(url: proxy.url.appendingPathComponent("stream_evaluations")))
        wait(for: [exchange.completed], timeout: 5)

        XCTAssertEqual(exchange.status, 401)
        XCTAssertEqual(proxy.records.map(\.path), ["/v1/stream_evaluations"])
        XCTAssertEqual(proxy.records.map(\.status), [401])
        XCTAssertEqual(proxy.count(of: "stream_evaluations"), 1)
    }

    func testNormalEndOfAStreamIsRecordedAsEnded() {
        MockURLProtocol.steps = [.response(status: 200), .data("a"), .finish]

        let exchange = client.send(URLRequest(url: proxy.url.appendingPathComponent("stream")))
        wait(for: [exchange.completed], timeout: 5)

        // A normal end is not an error, but the stream is no longer open.
        XCTAssertEqual(proxy.records.first?.status, 200)
        XCTAssertNil(proxy.records.first?.error)
        XCTAssertTrue(
            waitUntil(timeout: 5) { self.proxy.records.first?.ended == true },
            "a stream the backend ended normally is still recorded as open"
        )
    }

    func testBackendFailingMidStreamIsRecordedAndEndsTheClientReply() {
        MockURLProtocol.steps = [
            .response(status: 200),
            .data("a"),
            .wait(milliseconds: 100),
            .fail(URLError(.networkConnectionLost))
        ]

        let exchange = client.send(URLRequest(url: proxy.url.appendingPathComponent("stream")))
        wait(for: [exchange.completed], timeout: 5)

        XCTAssertEqual(exchange.body, "a")
        XCTAssertEqual(proxy.records.first?.status, 200)
        XCTAssertNotNil(proxy.records.first?.error)
    }

    func testUnreachableBackendIsRecordedAndClosesTheClientConnection() {
        MockURLProtocol.steps = [.fail(URLError(.cannotFindHost))]

        let exchange = client.send(URLRequest(url: proxy.url.appendingPathComponent("get_evaluations")))
        wait(for: [exchange.completed], timeout: 5)

        XCTAssertNotNil(exchange.error)
        XCTAssertNil(exchange.status)
        XCTAssertNil(proxy.records.first?.status)
        XCTAssertNotNil(proxy.records.first?.error)
    }

    func testClientClosingTheStreamCancelsTheBackendRequest() {
        // No .finish: the backend keeps the stream open until someone cancels it.
        MockURLProtocol.steps = [.response(status: 200), .data("a")]

        let exchange = client.send(URLRequest(url: proxy.url.appendingPathComponent("stream")))
        wait(for: [exchange.firstPiece], timeout: 5)
        XCTAssertEqual(proxy.records.first?.ended, false, "an open stream is recorded as ended")
        // Compared with a start value, not 0: the counter is shared by the whole process, and a
        // late cancel from the previous test could still land after its reset.
        let cancelledBefore = MockURLProtocol.stopLoadingCount

        exchange.task.cancel()

        XCTAssertTrue(
            waitUntil(timeout: 5) { MockURLProtocol.stopLoadingCount == cancelledBefore + 1 },
            "the backend request was not cancelled after the client closed its connection"
        )
        XCTAssertTrue(
            waitUntil(timeout: 5) { self.proxy.records.first?.ended == true },
            "a stream the client closed is still recorded as open"
        )
    }

    func testStopEndsAnOpenStreamAndRefusesNewRequests() {
        MockURLProtocol.steps = [.response(status: 200), .data("a")]

        let exchange = client.send(URLRequest(url: proxy.url.appendingPathComponent("stream")))
        wait(for: [exchange.firstPiece], timeout: 5)
        let cancelledBefore = MockURLProtocol.stopLoadingCount

        proxy.stop()

        wait(for: [exchange.completed], timeout: 5)
        XCTAssertTrue(
            waitUntil(timeout: 5) { MockURLProtocol.stopLoadingCount == cancelledBefore + 1 },
            "stop() did not cancel the backend request"
        )
        XCTAssertEqual(proxy.records.first?.ended, true, "a stream stop() closed is still recorded as open")

        let late = client.send(URLRequest(url: proxy.url.appendingPathComponent("get_evaluations")))
        wait(for: [late.completed], timeout: 5)
        XCTAssertNotNil(late.error)
        XCTAssertEqual(proxy.records.count, 1)
    }

    /// Polls `condition` on the calling thread, keeping its run loop turning.
    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return condition()
    }
}

/// The SDK's side of the proxy tests: a plain `URLSession` that records each reply piece by
/// piece. All callbacks run on one serial delegate queue; tests read the recorded values only
/// after waiting on an expectation fulfilled there.
private final class ProxyTestClient: NSObject, URLSessionDataDelegate {
    final class Exchange {
        let task: URLSessionDataTask
        let firstPiece = XCTestExpectation(description: "first body piece received")
        let completed = XCTestExpectation(description: "request completed")
        private let lock = NSLock()
        private var _status: Int?
        private var _body = Data()
        private var _error: Error?

        init(task: URLSessionDataTask) {
            self.task = task
        }

        var status: Int? { lock.withLock { _status } }
        var body: String { lock.withLock { String(decoding: _body, as: UTF8.self) } }
        var error: Error? { lock.withLock { _error } }

        fileprivate func received(status: Int) { lock.withLock { _status = status } }
        fileprivate func received(data: Data) {
            let isFirst = lock.withLock { () -> Bool in
                let isFirst = _body.isEmpty
                _body.append(data)
                return isFirst
            }
            if isFirst { firstPiece.fulfill() }
        }
        fileprivate func finished(error: Error?) {
            lock.withLock { _error = error }
            completed.fulfill()
        }
    }

    private var session: URLSession!
    private let lock = NSLock()
    private var exchanges: [Int: Exchange] = [:]

    override init() {
        super.init()
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: queue)
    }

    func send(_ request: URLRequest) -> Exchange {
        let task = session.dataTask(with: request)
        let exchange = Exchange(task: task)
        lock.withLock { exchanges[task.taskIdentifier] = exchange }
        task.resume()
        return exchange
    }

    func invalidate() {
        session.invalidateAndCancel()
    }

    private func exchange(for task: URLSessionTask) -> Exchange? {
        lock.withLock { exchanges[task.taskIdentifier] }
    }

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let http = response as? HTTPURLResponse {
            exchange(for: dataTask)?.received(status: http.statusCode)
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        exchange(for: dataTask)?.received(data: data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        exchange(for: task)?.finished(error: error)
    }
}
