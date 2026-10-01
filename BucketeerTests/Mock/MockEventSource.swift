import Foundation
@testable import Bucketeer

/// Test double for `EventSource`, the port of the JS `FakeEventSource`. It records what the
/// connection did to it, and the `simulate*` / `emit` drivers play the server's side.
///
/// Like the JS fake, the drivers fire even after `close()`, so a test can check that
/// `StreamConnection` ignores callbacks from a replaced event source.
final class MockEventSource: EventSource {
    var onOpen: (() -> Void)?
    var onMessage: ((SSEEvent) -> Void)?
    var onBytesReceived: (() -> Void)?
    var onError: ((_ status: Int?) -> Void)?

    private(set) var openedRequest: URLRequest?
    /// How many times `open(request:)` was called. Always 0 or 1 for a correct caller.
    private(set) var openCount = 0
    private(set) var closed = false
    private(set) var listeners: [String: [(SSEEvent) -> Void]] = [:]

    func addEventListener(_ type: String, _ listener: @escaping (SSEEvent) -> Void) {
        listeners[type, default: []].append(listener)
    }

    func open(request: URLRequest) {
        openedRequest = request
        openCount += 1
    }

    func close() {
        closed = true
    }

    // MARK: - Test drivers

    func simulateOpen() {
        onOpen?()
    }

    func simulateBytes() {
        onBytesReceived?()
    }

    /// An event with no `event:` line, delivered on the `message` channel.
    func simulateMessage(_ data: String) {
        onMessage?(SSEEvent(name: SSEParser.DEFAULT_EVENT_NAME, data: data))
    }

    /// Calls the listeners registered for `type`, the same as JS `emit`.
    func emit(_ type: String, _ data: String) {
        listeners[type]?.forEach { $0(SSEEvent(name: type, data: data)) }
    }

    func simulateError(status: Int? = nil) {
        onError?(status)
    }
}
