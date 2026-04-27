import Foundation

#if canImport(BackgroundTasks)
import BackgroundTasks

@available(iOS 13.0, tvOS 13.0, *)
final class EvaluationBackgroundTask {
    private weak var component: Component?
    private let queue: DispatchQueue

    // MARK: - Thread Safety
    // `isTaskEnabled` can be written from any caller queue (e.g. main thread via
    // performInitialFetch or fetchEvaluations completion) and read from the OS background
    // task system queue inside handleAppRefresh.
    // We protect it with NSLock instead of relying on queue confinement, so callers
    // do not need to be on a specific queue.
    private let lock = NSLock()
    private var _isTaskEnabled: Bool

    /// Thread-safe read of the enabled flag.
    var isTaskEnabled: Bool { lock.withLock { _isTaskEnabled } }

    init(component: Component, queue: DispatchQueue, enabled: Bool = false) {
        self.component = component
        self.queue = queue
        _isTaskEnabled = enabled
    }

    /// Enables the task so the next background refresh will execute a fetch.
    /// Thread-safe — may be called from any queue.
    func enable() {
        lock.withLock { _isTaskEnabled = true }
    }

    func scheduleAppRefresh() {
        let request = BGProcessingTaskRequest(identifier: getTaskIndentifier())
        request.requiresNetworkConnectivity = true
        let interval: TimeInterval = TimeInterval(component?.config.backgroundPollingInterval ?? Constant.DEFAULT_BACKGROUND_POLLING_INTERVAL_MILLIS)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval / 1000)

        do {
            try BGTaskScheduler.shared.submit(request)
            component?.config.logger?.debug(message: "[EvaluationBackgroundTask] The background task is scheduled.")
        } catch {
            component?.config.logger?.error(error)
        }
    }

    private func handleAppRefresh(_ task: BGTask) {
        component?.config.logger?.debug(message: "[EvaluationBackgroundTask] handleAppRefresh")
        // Schedule a new refresh task.
        scheduleAppRefresh()

        guard let component = self.component else { return }
        queue.async { [weak self] in
            // Read isTaskEnabled via the thread-safe getter (NSLock-protected).
            guard self?.isTaskEnabled == true else {
                component.config.logger?.debug(message: "[EvaluationBackgroundTask] Task not enabled, skipping")
                task.setTaskCompleted(success: true)
                return
            }
            if let taskQueue = self?.queue {
                BKTClient.fetchEvaluationsSync(
                    component: component,
                    dispatchQueue: taskQueue,
                    timeoutMillis: nil,
                    completion: { error in
                        task.setTaskCompleted(success: error == nil)
                        if let error {
                            self?.component?.config.logger?.error(error)
                        } else {
                            self?.component?.config.logger?.debug(message: "[EventBackgroundTask] success")
                        }
                    }
                )
            }
        }
        // Provide the background task with an expiration handler that cancels the operation.
        task.expirationHandler = { [weak self] in
            self?.component?.config.logger?.debug(message: "[EvaluationBackgroundTask] The background task is expired.")
            // Must set task completed, if we don't do this OS will throttle and limit our background task request
            // https://developer.apple.com/videos/play/wwdc2022/10142/
            task.setTaskCompleted(success: false)
        }
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension EvaluationBackgroundTask: ScheduledTask {
    func start() {
        scheduleAppRefresh()
    }

    func stop() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: getTaskIndentifier())
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension EvaluationBackgroundTask: BackgroundTask {
    func getTaskIndentifier() -> String {
        return BackgroundTaskIndentifier.fetchEvaluations
    }

    func handle(_ task: BGTask) {
        handleAppRefresh(task)
    }
}
#endif
