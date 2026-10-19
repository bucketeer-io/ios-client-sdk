import Foundation

/// `StreamingTask`'s own parts: the queue it runs on, its timers, a new event source per
/// connection, the polling fallback and the reconnect backoff. Behind protocols, so the task never
/// names a concrete class and tests can swap every part.
///
/// Not to be confused with `Component`: that is the per-client services every task reads
/// (config, user, interactors). This is created per `StreamingTask` (by `TaskScheduler`), and holds
/// a `Component` only to build the fallback, which needs one.
///
/// Owns the queue: the task, its timers, every event source and the fallback all use this one
/// serial SDK queue, and taking it from one place keeps them from drifting apart.
protocol StreamingTaskDependencies {
    /// The serial SDK queue.
    var queue: DispatchQueue { get }
    /// Timers for the recovery and the connection.
    var scheduler: StreamScheduler { get }
    /// A new event source for each connection attempt.
    func makeEventSource() -> EventSource
    /// The polling fallback, started when the stream gives up.
    func makeFallbackTask() -> StreamingFallbackTask
    /// Reconnect backoff for each new connection.
    func makeBackoff() -> StreamBackoff
}

final class StreamingTaskDependenciesImpl: StreamingTaskDependencies {
    let queue: DispatchQueue
    private let component: Component

    init(component: Component, queue: DispatchQueue) {
        self.component = component
        self.queue = queue
    }

    private(set) lazy var scheduler: StreamScheduler = DispatchStreamScheduler(queue: queue)

    func makeEventSource() -> EventSource {
        return URLSessionEventSource(queue: queue, logger: component.config.logger)
    }

    /// Created enabled: the stream only opens after the initial fetch, so the fallback never
    /// waits for `TaskScheduler.enableEvaluationTask()`.
    func makeFallbackTask() -> StreamingFallbackTask {
        return EvaluationForegroundTask(component: component, queue: queue, enabled: true)
    }

    func makeBackoff() -> StreamBackoff {
        return StreamBackoff()
    }
}
