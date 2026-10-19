import Foundation

/// A scripted server for `URLSessionEventSource` tests. Apple's `URLProtocol` hook intercepts
/// requests inside a real `URLSession`, so the real delegate code runs against these steps
/// (the iOS stand-in for injecting a fake `fetch` in the JS tests).
///
/// The state is static, so tests that use it must not run in parallel with each other. XCTest
/// runs them one at a time today (the Makefile doesn't enable parallel testing). Call `reset()`
/// in `setUp` and `tearDown`.
final class MockURLProtocol: URLProtocol {
    enum Step {
        case response(status: Int)
        case data(String)
        /// The server ends the stream normally.
        case finish
        case fail(URLError)
        /// Pauses the server between two steps. Without a pause, a `.fail` right after `.data`
        /// makes URLSession drop data it has not delivered yet, which a real server never causes.
        case wait(milliseconds: Int)
    }

    /// Played in order by every request. With no `.finish` or `.fail`, the stream stays open
    /// until the client cancels it.
    static var steps: [Step] = []
    private(set) static var lastRequest: URLRequest?
    /// The body as the server received it. `URLProtocol` gets it as `httpBodyStream`, not
    /// `httpBody`.
    private(set) static var lastRequestBody: Data?

    static func reset() {
        steps = []
        lastRequest = nil
        lastRequestBody = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        Self.lastRequest = request
        Self.lastRequestBody = request.httpBody ?? Self.readAll(request.httpBodyStream)
        for step in Self.steps {
            switch step {
            case .response(let status):
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: status,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "text/event-stream"]
                )!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            case .data(let text):
                client?.urlProtocol(self, didLoad: Data(text.utf8))
            case .finish:
                client?.urlProtocolDidFinishLoading(self)
                return
            case .fail(let error):
                client?.urlProtocol(self, didFailWithError: error)
                return
            case .wait(let milliseconds):
                // Keeps this loading thread's run loop turning, so URLSession can deliver what
                // it already has.
                RunLoop.current.run(until: Date().addingTimeInterval(Double(milliseconds) / 1_000))
            }
        }
    }

    override func stopLoading() {
    }

    private static func readAll(_ stream: InputStream?) -> Data? {
        guard let stream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
