import Foundation

/// One SSE connection attempt over a dedicated `URLSession`. Port of the JS `FetchEventSource`.
///
/// Not thread-safe: call it on the serial SDK queue, the same queue passed to `init`. URLSession
/// delivers its delegate callbacks on that queue, so `readyState` and the parser need no lock.
///
/// Each instance owns its own `URLSession`, and `close()` invalidates it. A `URLSession` keeps a
/// strong reference to its delegate until it is invalidated, so an instance that is never closed
/// is never freed. `StreamConnection` closes it on every path.
final class URLSessionEventSource: NSObject, EventSource, URLSessionDataDelegate {
    private enum ReadyState {
        case connecting
        case open
        case closed
    }

    var onOpen: (() -> Void)?
    var onMessage: ((SSEEvent) -> Void)?
    var onBytesReceived: (() -> Void)?
    var onError: ((_ status: Int?) -> Void)?

    private let queue: DispatchQueue
    private let configuration: URLSessionConfiguration
    private let logger: Logger?
    private var readyState: ReadyState = .connecting
    private var listeners: [String: [(SSEEvent) -> Void]] = [:]
    private var parser = SSEParser()
    private var session: URLSession?

    /// - Parameter queue: The serial SDK queue, the same instance the `DispatchStreamScheduler`
    ///   uses. Every callback is delivered on it.
    init(queue: DispatchQueue,
         configuration: URLSessionConfiguration = URLSessionEventSource.makeConfiguration(),
         logger: Logger? = nil) {
        self.queue = queue
        self.configuration = configuration
        self.logger = logger
    }

    static func makeConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        // Longer than the 70s watchdog, so our own timer decides when a silent stream is dead.
        configuration.timeoutIntervalForRequest = Constant.Streaming.REQUEST_TIMEOUT_SECONDS
        // A precaution: a stream must never be answered from a cache.
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        // Fail fast when offline, so the retry and polling fallback logic runs.
        configuration.waitsForConnectivity = false
        return configuration
    }

    /// A copy of `request` with the stream timeout and the SSE default headers. Headers the caller
    /// already set win, as in JS. The method is left as is: a `URLRequest` starts as GET, so "not
    /// set" can't be told apart from GET, and the caller sets POST.
    static func prepareRequest(_ request: URLRequest) -> URLRequest {
        var prepared = request
        prepared.timeoutInterval = Constant.Streaming.REQUEST_TIMEOUT_SECONDS
        if prepared.value(forHTTPHeaderField: "Content-Type") == nil {
            prepared.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if prepared.value(forHTTPHeaderField: "Accept") == nil {
            prepared.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        }
        return prepared
    }

    func addEventListener(_ type: String, _ listener: @escaping (SSEEvent) -> Void) {
        listeners[type, default: []].append(listener)
    }

    func open(request: URLRequest) {
        guard readyState != .closed else { return }
        let delegateQueue = OperationQueue()
        delegateQueue.underlyingQueue = queue
        delegateQueue.maxConcurrentOperationCount = 1
        // Never reuse ApiClientImpl's session: it blocks the SDK queue until the response
        // completes, and a stream never completes.
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)
        self.session = session
        session.dataTask(with: Self.prepareRequest(request)).resume()
    }

    func close() {
        readyState = .closed
        session?.invalidateAndCancel()
        session = nil
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard readyState != .closed else {
            completionHandler(.cancel)
            return
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            // Only possible with a non-HTTP URL. Treated like a network error.
            completionHandler(.cancel)
            readyState = .closed
            onError?(nil)
            return
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            // `.cancel` also makes URLSession report a cancelled completion later. readyState is
            // closed by then, so that one is ignored and onError fires only once.
            completionHandler(.cancel)
            readyState = .closed
            logger?.debug(message: "[URLSessionEventSource] stream request failed with HTTP \(httpResponse.statusCode)")
            onError?(httpResponse.statusCode)
            return
        }
        completionHandler(.allow)
        readyState = .open
        onOpen?()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard readyState == .open else { return }
        // Every chunk, even a heartbeat comment alone, is proof the connection is alive.
        onBytesReceived?()
        for event in parser.append(data) {
            dispatch(event)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // Covers the cancelled completion after close() and after a non-2xx `.cancel`.
        guard readyState != .closed else { return }
        readyState = .closed
        // A normal end of stream (no error) also reports nil: the caller treats it as a retry,
        // as in JS.
        onError?(nil)
    }

    // MARK: - Private

    private func dispatch(_ event: SSEEvent) {
        if let handlers = listeners[event.name], !handlers.isEmpty {
            handlers.forEach { $0(event) }
        } else if event.name == SSEParser.DEFAULT_EVENT_NAME {
            onMessage?(event)
        } else {
            // A named event with no listener is dropped, never sent to onMessage, so an unknown
            // event can't be mistaken for evaluation data.
            logger?.debug(message: "[URLSessionEventSource] dropped event \"\(event.name)\" with no listener")
        }
    }
}
