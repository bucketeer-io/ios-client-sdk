import Foundation

struct StreamConnectionErrorInfo: Equatable {
    /// true: retrying can never work (for example, a bad API key). The caller must not schedule
    /// streaming recovery.
    let terminal: Bool
}

struct StreamConnectionCallbacks {
    let onOpen: () -> Void
    /// Called only when this connection gives up: a terminal status, a non-recoverable status,
    /// or unhealthy for more than 120s. Short drops heal on their own and do NOT call this.
    let onError: (StreamConnectionErrorInfo) -> Void
}

/// Keeps exactly one healthy SSE connection open, reconnecting with backoff when it breaks.
/// Port of the JS `StreamConnection.ts`.
///
/// Not thread-safe: call it, and deliver its event sources' callbacks, on the serial SDK queue
/// (the scheduler's queue). It never dispatches on its own, so its callbacks run on the
/// caller's queue. Holds its closures strongly: callers pass `[weak self]` closures.
/// Create a new one each time a stream opens, as JS `StreamingTask` does (in each `openStream()`).
/// Don't `start()` a stopped one again: its unhealthy window and backoff carry over.
final class StreamConnection {
    private let makeEventSource: () -> EventSource
    private let requestBuilder: () throws -> URLRequest
    private let events: [String: (String) -> Void]
    private let onUnhandledMessage: ((String) -> Void)?
    private let callbacks: StreamConnectionCallbacks
    private let scheduler: StreamScheduler
    private var backoff: StreamBackoff
    private let logger: Logger?

    private var eventSource: EventSource?
    private var watchdog: DispatchWorkItem?
    private var reconnectTimer: DispatchWorkItem?
    private var backoffResetTimer: DispatchWorkItem?
    /// Scheduler time when the current unhealthy period started. nil while healthy.
    private var unhealthySince: Int64?
    private var isActive = false

    /// - Parameters:
    ///   - makeEventSource: Creates a new event source for each connection attempt.
    ///   - requestBuilder: Runs on every (re)connect, so each attempt sends the latest user
    ///     attributes and cache state. A throw is reported as a non-terminal error.
    ///   - events: Handlers for named events (for example `put`, `patch`, `error`). A `message`
    ///     key is ignored: that channel belongs to this class (see `onUnhandledMessage`).
    ///   - onUnhandledMessage: Receives the data of unnamed events (the SSE standard's default
    ///     type `message`). Liveness tracking does not depend on this being set.
    init(makeEventSource: @escaping () -> EventSource,
         requestBuilder: @escaping () throws -> URLRequest,
         events: [String: (String) -> Void],
         onUnhandledMessage: ((String) -> Void)? = nil,
         callbacks: StreamConnectionCallbacks,
         scheduler: StreamScheduler,
         backoff: StreamBackoff = StreamBackoff(),
         logger: Logger? = nil) {
        self.makeEventSource = makeEventSource
        self.requestBuilder = requestBuilder
        self.events = events
        self.onUnhandledMessage = onUnhandledMessage
        self.callbacks = callbacks
        self.scheduler = scheduler
        self.backoff = backoff
        self.logger = logger
    }

    func start() {
        isActive = true
        openConnection()
    }

    /// External reconnect (for example after `updateUserAttributes()`): a fresh request and a
    /// reset backoff.
    ///
    /// Deliberately does NOT clear `unhealthySince`: an already-unhealthy connection must keep
    /// its 120s give-up deadline, or an app calling `updateUserAttributes()` more often than
    /// that would postpone the polling fallback forever while the stream endpoint stays down.
    /// A healthy connection already has no deadline, and `markHealthy()` keeps clearing it on
    /// real liveness, so this only affects the unhealthy case.
    func reconnect() {
        guard isActive else { return }
        backoff.reset()
        openConnection()
    }

    func stop() {
        isActive = false
        clearReconnectTimer()
        closeEventSource()
    }

    // MARK: - Private

    private func openConnection() {
        // Single-connection rule: cancel any pending retry and close the live event source
        // before opening a new one, so a reconnect() racing a scheduled retry can't produce two.
        clearReconnectTimer()
        closeEventSource()

        let request: URLRequest
        do {
            request = try requestBuilder()
        } catch {
            // openConnection() also runs from a timer, where a throw has nowhere to go. Same
            // give-up path as an error status: the caller decides what happens next.
            logger?.error(error)
            closeEventSource()
            callbacks.onError(StreamConnectionErrorInfo(terminal: false))
            return
        }

        let es = makeEventSource()
        eventSource = es

        es.onOpen = { [weak self, weak es] in
            guard let self, self.isCurrent(es) else { return }
            self.armBackoffReset()
            self.resetWatchdog()
            self.callbacks.onOpen()
        }
        // Every chunk, even a heartbeat comment alone, proves the connection is delivering bytes.
        es.onBytesReceived = { [weak self, weak es] in
            guard let self, self.isCurrent(es) else { return }
            self.markHealthy()
        }
        // Wired every time, whether or not onUnhandledMessage is set, so liveness tracking
        // can't be switched off by the caller's configuration.
        es.onMessage = { [weak self, weak es] event in
            guard let self, self.isCurrent(es) else { return }
            self.markHealthy()
            self.onUnhandledMessage?(event.data)
        }
        for (name, handler) in events where name != SSEParser.DEFAULT_EVENT_NAME {
            es.addEventListener(name) { [weak self, weak es] event in
                guard let self, self.isCurrent(es) else { return }
                self.markHealthy()
                handler(event.data)
            }
        }
        es.onError = { [weak self, weak es] status in
            guard let self, self.isCurrent(es) else { return }
            self.handleError(status: status)
        }

        es.open(request: request)
        // Also the connect timeout: if the request hangs without opening, the watchdog fires
        // and scheduleReconnect() bounds the retries.
        resetWatchdog()
    }

    /// false for callbacks from an event source that was already replaced or closed.
    private func isCurrent(_ es: EventSource?) -> Bool {
        guard let es else { return false }
        return eventSource === es
    }

    private func handleError(status: Int?) {
        if StreamHttpStatus.isTerminal(status) {
            closeEventSource()
            callbacks.onError(StreamConnectionErrorInfo(terminal: true))
        } else if StreamHttpStatus.isRecoverable(status) {
            scheduleReconnect()
        } else {
            // Depends on the request body, which can change later: give up for now and let
            // the caller decide.
            closeEventSource()
            callbacks.onError(StreamConnectionErrorInfo(terminal: false))
        }
    }

    /// Retries with backoff, bounded by the unhealthy window, whether or not the stream ever
    /// opened. After giving up, nothing is scheduled and `isActive` stays true, as in JS.
    private func scheduleReconnect() {
        closeEventSource()
        guard isActive else { return }
        let now = scheduler.nowMillis
        let since = unhealthySince ?? now
        unhealthySince = since
        if now - since > Constant.Streaming.UNHEALTHY_FALLBACK_TIMEOUT_MILLIS {
            callbacks.onError(StreamConnectionErrorInfo(terminal: false))
            return
        }
        clearReconnectTimer()
        let work = DispatchWorkItem { [weak self] in
            self?.openConnection()
        }
        reconnectTimer = work
        scheduler.schedule(afterMillis: backoff.nextDelayMillis(), work)
    }

    private func markHealthy() {
        unhealthySince = nil
        resetWatchdog()
    }

    /// Once the connection has stayed open for 60s, the next drop backs off from the start.
    /// closeEventSource() cancels this if the connection drops first, so a flapping connection
    /// keeps escalating.
    private func armBackoffReset() {
        backoffResetTimer?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.backoff.reset()
        }
        backoffResetTimer = work
        scheduler.schedule(afterMillis: Constant.Streaming.RESET_INTERVAL_MILLIS, work)
    }

    private func resetWatchdog() {
        cancelWatchdog()
        let work = DispatchWorkItem { [weak self] in
            self?.scheduleReconnect()
        }
        watchdog = work
        scheduler.schedule(afterMillis: Constant.Streaming.WATCHDOG_TIMEOUT_MILLIS, work)
    }

    private func cancelWatchdog() {
        watchdog?.cancel()
        watchdog = nil
    }

    private func clearReconnectTimer() {
        reconnectTimer?.cancel()
        reconnectTimer = nil
    }

    private func closeEventSource() {
        cancelWatchdog()
        backoffResetTimer?.cancel()
        backoffResetTimer = nil
        eventSource?.close()
        eventSource = nil
    }
}
