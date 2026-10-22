import Foundation

/// One SSE connection attempt. Create a new one per attempt, never reuse it. Set the callbacks
/// and listeners first, then call `open`.
///
/// Not thread-safe: call every method, and set every callback, on the serial SDK queue.
/// Callbacks are delivered on that same queue. None are delivered after `close()`, except the
/// remaining events of a chunk whose own callback called `close()`. `StreamConnection` ignores
/// callbacks from a closed event source anyway.
protocol EventSource: AnyObject {
    /// The server answered with a 2xx status.
    var onOpen: (() -> Void)? { get set }
    /// Events with no name (the SSE standard's default type "message").
    var onMessage: ((SSEEvent) -> Void)? { get set }
    /// Some bytes arrived (an event, part of one, or a heartbeat comment). Proof the connection
    /// is alive. It is a separate callback so `onMessage` always carries a real event.
    var onBytesReceived: (() -> Void)? { get set }
    /// The attempt ended: an HTTP error status, a network error (nil), or the server closed the
    /// stream (nil). Delivered at most once. There is no `terminal` flag: the only terminal
    /// signal is the HTTP status.
    var onError: ((_ status: Int?) -> Void)? { get set }
    /// Events with this name go to `listener`. A named event with no listener is dropped,
    /// never sent to `onMessage`.
    func addEventListener(_ type: String, _ listener: @escaping (SSEEvent) -> Void)
    func open(request: URLRequest)
    func close()
}
