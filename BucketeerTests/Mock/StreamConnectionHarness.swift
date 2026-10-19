import Foundation
@testable import Bucketeer

/// Shared setup for the `StreamConnection` tests: a fake clock, every `MockEventSource` the
/// connection creates (like JS `FakeEventSource.instances`), and recorders for everything the
/// connection reports. Jitter is pinned to 0, so retry delays are exactly 1s, 2s, 4s, ... 30s.
final class StreamConnectionHarness {
    struct TestError: Error {}

    let scheduler = MockStreamScheduler()
    let logger = MockLogger()

    private(set) var sources: [MockEventSource] = []
    /// How many times the connection reported `callbacks.onOpen`.
    private(set) var openCount = 0
    /// Events delivered to the `events` handlers, in order.
    private(set) var received: [SSEEvent] = []
    /// Data delivered to `onUnhandledMessage`, in order.
    private(set) var unhandled: [String] = []
    private(set) var errors: [StreamConnectionErrorInfo] = []
    private(set) var builderCallCount = 0

    private let eventNames: [String]
    private let recordsUnhandledMessages: Bool
    private let requestBuilder: (_ attempt: Int) throws -> URLRequest

    /// - Parameters:
    ///   - eventNames: Names passed in the `events` map. Each handler records into `received`.
    ///   - recordsUnhandledMessages: Whether to pass an `onUnhandledMessage` at all.
    ///   - requestBuilder: Gets the 1-based build count. By default returns
    ///     `https://example.test/sse?attempt=<n>`.
    init(eventNames: [String] = ["put", "patch", "error"],
         recordsUnhandledMessages: Bool = true,
         requestBuilder: ((_ attempt: Int) throws -> URLRequest)? = nil) {
        self.eventNames = eventNames
        self.recordsUnhandledMessages = recordsUnhandledMessages
        self.requestBuilder = requestBuilder ?? { attempt in
            URLRequest(url: URL(string: "https://example.test/sse?attempt=\(attempt)")!)
        }
    }

    lazy var connection: StreamConnection = makeConnection()

    /// The most recently created event source. Read it with `try XCTUnwrap(h.latest)`, so
    /// "nothing opened" fails the test cleanly instead of crashing.
    var latest: MockEventSource? {
        return sources.last
    }

    func start() {
        connection.start()
    }

    func advance(_ millis: Int64) {
        scheduler.advance(byMillis: millis)
    }

    private func makeConnection() -> StreamConnection {
        var events: [String: (String) -> Void] = [:]
        for name in eventNames {
            events[name] = { [unowned self] data in
                self.received.append(SSEEvent(name: name, data: data))
            }
        }
        let onUnhandledMessage: ((String) -> Void)? = recordsUnhandledMessages
            ? { [unowned self] data in self.unhandled.append(data) }
            : nil
        return StreamConnection(
            makeEventSource: { [unowned self] in
                let source = MockEventSource()
                self.sources.append(source)
                return source
            },
            requestBuilder: { [unowned self] in
                self.builderCallCount += 1
                return try self.requestBuilder(self.builderCallCount)
            },
            events: events,
            onUnhandledMessage: onUnhandledMessage,
            callbacks: StreamConnectionCallbacks(
                onOpen: { [unowned self] in self.openCount += 1 },
                onError: { [unowned self] info in self.errors.append(info) }
            ),
            scheduler: scheduler,
            backoff: StreamBackoff(random: { 0 }),
            logger: logger
        )
    }
}
