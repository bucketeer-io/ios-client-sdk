import Foundation
import XCTest
@testable import Bucketeer

/// Drives one real `URLSessionEventSource` against `MockURLProtocol` and records every callback.
///
/// Same rules as production (the serial SDK queue): every call into the event source goes
/// through `queue.sync`, the callbacks arrive on `queue`, and the recorded values are only
/// touched there. Read them with `read { $0.errors }` after waiting on `ended`.
final class URLSessionEventSourceHarness {
    static let queueKey = DispatchSpecificKey<String>()
    static let queueTag = "event-source-queue"

    let queue: DispatchQueue
    let logger = MockLogger()
    private(set) var source: URLSessionEventSource?

    /// Fulfilled by the first `onError`, the same idea as JS `until(t.ended)`.
    let ended = XCTestExpectation(description: "onError called")
    let opened = XCTestExpectation(description: "onOpen called")

    private(set) var log: [String] = []
    private(set) var openCount = 0
    private(set) var bytesCount = 0
    private(set) var messages: [SSEEvent] = []
    /// Events delivered to the listeners registered with `listenerNames`.
    private(set) var received: [SSEEvent] = []
    private(set) var errors: [Int?] = []
    /// Callbacks that ran anywhere other than `queue`. Must stay 0.
    private(set) var offQueueCallbacks = 0

    init(steps: [MockURLProtocol.Step], listenerNames: [String] = []) {
        MockURLProtocol.steps = steps
        ended.assertForOverFulfill = false
        queue = DispatchQueue(label: "io.bucketeer.test.urlSessionEventSource")
        queue.setSpecific(key: Self.queueKey, value: Self.queueTag)

        let configuration = URLSessionEventSource.makeConfiguration()
        configuration.protocolClasses = [MockURLProtocol.self]
        let source = URLSessionEventSource(queue: queue, configuration: configuration, logger: logger)
        self.source = source
        queue.sync {
            source.onOpen = { [weak self] in
                self?.record("open")
                self?.openCount += 1
                self?.opened.fulfill()
            }
            source.onBytesReceived = { [weak self] in
                self?.record("bytes")
                self?.bytesCount += 1
            }
            source.onMessage = { [weak self] event in
                self?.record("message:\(event.data)")
                self?.messages.append(event)
            }
            source.onError = { [weak self] status in
                self?.record("error:\(String(describing: status))")
                self?.errors.append(status)
                self?.ended.fulfill()
            }
            for name in listenerNames {
                source.addEventListener(name) { [weak self] event in
                    self?.record("\(name):\(event.data)")
                    self?.received.append(event)
                }
            }
        }
    }

    static func request(_ url: String = "https://example.test/sse") -> URLRequest {
        return URLRequest(url: URL(string: url)!)
    }

    func open(_ request: URLRequest = URLSessionEventSourceHarness.request()) {
        queue.sync { source?.open(request: request) }
    }

    /// Closes on the queue, as production does. Safe to call more than once.
    func close() {
        queue.sync { source?.close() }
    }

    /// Drops the harness's reference, so a test can check the event source gets freed.
    func releaseSource() {
        queue.sync { source = nil }
    }

    /// Reads recorded values on the queue, where they are written.
    func read<T>(_ body: (URLSessionEventSourceHarness) -> T) -> T {
        return queue.sync { body(self) }
    }

    private func record(_ entry: String) {
        if DispatchQueue.getSpecific(key: Self.queueKey) != Self.queueTag {
            offQueueCallbacks += 1
        }
        log.append(entry)
    }
}
