import Foundation

/// Keeps evaluations up to date over the SSE stream, falling back to polling while the stream
/// is down and trying the stream again after 5 minutes. Port of the JS `StreamingTask.ts`.
/// `TaskScheduler` uses it in place of `EvaluationForegroundTask` when streaming is enabled.
///
/// Differences from JS:
/// - The stream opens only after `enable()` (called after the initial fetch), the same switch
///   `EvaluationForegroundTask` uses. A stream failing fast during init would otherwise start a
///   fallback fetch next to the init fetch.
/// - `TaskScheduler` reuses this object across background/foreground (JS builds a new one), so:
///   `start()` while running does nothing, `terminalFailure` survives `stop()`/`start()`, and
///   every `openStream()` builds a new `StreamConnection`.
///
/// Threading: every field except the two flags is used only on `queue`, the serial SDK queue.
/// The entry points are called from the main thread (`TaskScheduler`) or the app's thread
/// (`BKTClient`), so they hop onto `queue` with `async`, never `sync`: `sync` from the main thread
/// could freeze the app behind a blocking poll. The flags are set before the hop, behind a lock,
/// because `shouldNotify` reads `isRunning` on the main thread: after `stop()` returns, no update
/// listener fires and no stream data waiting in the queue is applied.
final class StreamingTask: ScheduledTask {
    private let component: Component
    private let dependencies: StreamingTaskDependencies
    private let queue: DispatchQueue

    private let lock = NSLock()
    private var _isRunning = false
    private var _isEnabled = false

    private var connection: StreamConnection?
    private var fallbackTask: StreamingFallbackTask?
    private var recoveryWorkItem: DispatchWorkItem?
    /// Captured by `buildRequest()`. `onOpen` clears the flag with it, so only a request that
    /// actually carried these attributes can clear the flag they belong to.
    private var lastRequestAttributesState: UserAttributesState?
    /// Set on a terminal failure (bad API key, streaming unsupported). Never reset: only destroy +
    /// initialize brings streaming back, as in JS.
    private var terminalFailure = false
    /// The merged reconnect waiting to run, see `onUserAttributesUpdated()`.
    private var pendingReconnect: DispatchWorkItem?

    /// - Parameters:
    ///   - component: The per-client services the task reads: config, user and the evaluation
    ///     interactor. The same `Component` every task gets.
    ///   - dependencies: The task's own parts: the queue they all share, the timers, event
    ///     sources, fallback and backoff. `StreamingTaskDependenciesImpl` in production.
    init(component: Component, dependencies: StreamingTaskDependencies) {
        self.component = component
        self.dependencies = dependencies
        self.queue = dependencies.queue
    }

    var isRunning: Bool { lock.withLock { _isRunning } }
    private var isEnabled: Bool { lock.withLock { _isEnabled } }

    func start() {
        lock.withLock { _isRunning = true }
        queue.async { [weak self] in
            self?.openIfReady()
        }
    }

    /// Called after the initial fetch. Opens the stream if the task is running.
    func enable() {
        lock.withLock { _isEnabled = true }
        queue.async { [weak self] in
            self?.openIfReady()
        }
    }

    func stop() {
        lock.withLock { _isRunning = false }
        // Holds self strongly on purpose: BKTClient.destroy() releases the task right after
        // stop(), and the stream must still be closed (URLSession keeps the event source alive
        // until it is invalidated).
        queue.async { [self] in
            self.connection?.stop()
            self.connection = nil
            self.stopFallback()
            self.pendingReconnect?.cancel()
            self.pendingReconnect = nil
        }
    }

    /// Reconnects now so the stream sends the new user attributes. Called after the 200ms merge in
    /// `onUserAttributesUpdated()`.
    func reconnect() {
        queue.async { [weak self] in
            guard let self, self.isRunning, self.isEnabled else { return }
            // The stream can't come back (bad API key, streaming unsupported). The fallback keeps
            // polling on its own schedule, as polling mode does after updateUserAttributes().
            guard !self.terminalFailure else { return }
            if let connection = self.connection {
                // The connection builds the request again, with the new attributes.
                connection.reconnect()
            } else {
                // On the fallback: go straight back to streaming. The fallback keeps polling
                // until onOpen proves the new stream works, so there is no gap.
                self.openStream()
            }
        }
    }

    /// Called by `TaskScheduler` when the user attributes change. A burst of calls (several
    /// attributes set at login) becomes one `reconnect()`, 200ms after the last call. JS keeps
    /// this merge in its TaskScheduler with a plain setTimeout; here it uses the task's own
    /// scheduler, the only timer tests can control, so the task owns it.
    func onUserAttributesUpdated() {
        queue.async { [weak self] in
            guard let self, self.isRunning else { return }
            self.pendingReconnect?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.reconnect()
            }
            self.pendingReconnect = work
            self.dependencies.scheduler.schedule(afterMillis: Constant.Streaming.RECONNECT_DEBOUNCE_MILLIS, work)
        }
    }

    // MARK: - Private, on queue

    /// Opens the stream once per run. A second `start()` (TaskScheduler calls it in its init and
    /// again on didActivate) or `enable()` finds the stream or the fallback already running.
    private func openIfReady() {
        guard isRunning, isEnabled, connection == nil, fallbackTask == nil else { return }
        if terminalFailure {
            // Back from the background after a terminal failure: poll the way polling mode
            // does on foreground, without an immediate fetch.
            startFallback(immediately: false)
        } else {
            openStream()
        }
    }

    private func openStream() {
        // reconnect() and the recovery both open a stream while a recovery may still be armed.
        // Cancel it here, or it could fire later and open a second connection.
        cancelRecovery()

        let dependencies = self.dependencies
        let connection = StreamConnection(
            makeEventSource: { dependencies.makeEventSource() },
            requestBuilder: { [weak self] in
                guard let self else {
                    throw BKTError.illegalState(message: "StreamingTask was released")
                }
                return try self.buildRequest()
            },
            // Backend event names: `put` is the full snapshot sent after connecting, `patch` a
            // change, `error` a server error reported right before it closes the stream.
            events: [
                "put": { [weak self] data in self?.handleData(data) },
                "patch": { [weak self] data in self?.handleData(data) },
                "error": { [weak self] data in self?.logServerError(data) }
            ],
            // Events with no name. This backend always names its events, so this is a fallback.
            onUnhandledMessage: { [weak self] data in self?.handleData(data) },
            callbacks: StreamConnectionCallbacks(
                onOpen: { [weak self] in
                    // An open already waiting in the queue when stop() was called. Its snapshot
                    // will never be applied, so it must not clear the attributes flag.
                    // stop()'s cleanup stops the fallback.
                    guard let self, self.isRunning else { return }
                    self.stopFallback()
                    self.clearUserAttributesUpdated()
                },
                onError: { [weak self] info in
                    self?.handleError(info)
                }
            ),
            scheduler: dependencies.scheduler,
            backoff: dependencies.makeBackoff(),
            logger: component.config.logger
        )
        self.connection = connection
        connection.start()
    }

    /// Runs on every (re)connect, so each attempt sends the latest attributes and cached state.
    private func buildRequest() throws -> URLRequest {
        let config = component.config
        let interactor = component.evaluationInteractor
        // Captured before the user is read: updateUserAttributes() runs on the app's thread, and
        // this order means a change in between can only leave the flag set, never clear it for
        // attributes this request does not carry.
        lastRequestAttributesState = interactor.userAttributesState
        let cached = interactor.cachedEvaluationsState
        let body = StreamEvaluationsRequestBody(
            tag: config.featureTag,
            user: component.userHolder.user,
            sourceId: config.sourceId,
            sdkVersion: config.sdkVersion,
            userEvaluationsId: cached.userEvaluationsId,
            evaluatedAt: cached.evaluatedAt
        )
        var request = URLRequest(url: config.apiEndpoint.appendingPathComponent(Constant.Streaming.STREAM_EVALUATIONS_PATH))
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = [
            "Authorization": config.apiKey,
            "Content-Type": "application/json",
            "Accept": "text/event-stream"
        ]
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func handleData(_ data: String) {
        // Data already waiting in the queue when stop() was called.
        guard isRunning else { return }
        let response: GetEvaluationsResponse
        do {
            // Strict on purpose, see StreamErrorEvent: the backend always sends every field.
            response = try JSONDecoder().decode(GetEvaluationsResponse.self, from: Data(data.utf8))
        } catch {
            component.config.logger?.debug(message: "[StreamingTask] dropped a stream event that is not an evaluations payload: \(error)")
            return
        }
        component.evaluationInteractor.applyStreamedEvaluations(response, shouldNotify: { [weak self] in
            self?.isRunning ?? false
        })
    }

    private func logServerError(_ data: String) {
        let message: String
        if let event = try? JSONDecoder().decode(StreamErrorEvent.self, from: Data(data.utf8)) {
            message = "code: \(event.code ?? "nil"), message: \(event.message ?? "nil")"
        } else {
            message = data
        }
        component.config.logger?.warn(message: "[StreamingTask] server reported a stream error: \(message)")
    }

    /// The connection gave up (see StreamConnectionCallbacks.onError).
    private func handleError(_ info: StreamConnectionErrorInfo) {
        guard isRunning else { return }
        connection?.stop()
        connection = nil
        startFallback(immediately: true)
        if info.terminal {
            terminalFailure = true
            component.config.logger?.warn(
                message: "[StreamingTask] streaming has stopped permanently (terminal error); "
                    + "falling back to polling until the client is destroyed and initialized again"
            )
        } else {
            scheduleRecovery()
        }
    }

    /// Clears the flag only with the state this connection's request carried. A failed connect
    /// never gets here, so the flag survives for the fallback's next poll.
    private func clearUserAttributesUpdated() {
        guard let state = lastRequestAttributesState else { return }
        component.evaluationInteractor.clearUserAttributesUpdated(state: state)
    }

    /// `immediately`: fetch right away instead of one pollingInterval later, so a stream drop
    /// doesn't leave evaluations stale.
    private func startFallback(immediately: Bool) {
        guard fallbackTask == nil else { return }
        let fallbackTask = dependencies.makeFallbackTask()
        self.fallbackTask = fallbackTask
        fallbackTask.start(immediately: immediately)
    }

    private func stopFallback() {
        fallbackTask?.stop()
        fallbackTask = nil
        cancelRecovery()
    }

    /// Tries the stream again after 5 minutes. The fallback keeps polling until onOpen proves
    /// the new stream works.
    private func scheduleRecovery() {
        cancelRecovery()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isRunning else { return }
            self.openStream()
        }
        recoveryWorkItem = work
        dependencies.scheduler.schedule(afterMillis: Constant.Streaming.RECOVERY_INTERVAL_MILLIS, work)
    }

    private func cancelRecovery() {
        recoveryWorkItem?.cancel()
        recoveryWorkItem = nil
    }
}
