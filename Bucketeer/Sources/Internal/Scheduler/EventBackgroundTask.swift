import Foundation

#if canImport(BackgroundTasks)
import BackgroundTasks

@available(iOS 13.0, tvOS 13.0, *)
final class EventBackgroundTask {
    private weak var component: Component?
    private let queue: DispatchQueue

    init(component: Component, queue: DispatchQueue) {
        self.component = component
        self.queue = queue
    }

    func scheduleAppRefresh() {
        let request = BGProcessingTaskRequest(identifier: getTaskIndentifier())
        request.requiresNetworkConnectivity = true
        let interval: TimeInterval = TimeInterval(component?.config.eventsFlushInterval ?? Constant.DEFAULT_FLUSH_INTERVAL_MILLIS)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval / 1000)

        do {
            try BGTaskScheduler.shared.submit(request)
            component?.config.logger?.debug(message: "[EventBackgroundTask] The background task is scheduled.")
        } catch {
            component?.config.logger?.error(error)
        }
    }

    private func handleAppRefresh(_ task: BGTask) {
        component?.config.logger?.debug(message: "[EventBackgroundTask] handleAppRefresh")
        // Schedule a new refresh task.
        scheduleAppRefresh()

        guard let component = self.component else { return }
        queue.async {
            BKTClient.flushSync(component: component) { [weak self] error in
                task.setTaskCompleted(success: error == nil)
                if let error {
                    self?.component?.config.logger?.error(error)
                } else {
                    self?.component?.config.logger?.debug(message: "[EventBackgroundTask] success")
                }
            }
        }
        // Provide the background task with an expiration handler that cancels the operation.
        task.expirationHandler = { [weak self] in
            self?.component?.config.logger?.debug(message: "[EventBackgroundTask] The background task is expired.")
            // Must set task completed, if we don't do this OS will throttle and limit our background task request
            // https://developer.apple.com/videos/play/wwdc2022/10142/
            task.setTaskCompleted(success: false)
        }
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension EventBackgroundTask: ScheduledTask {
    func start() {
        scheduleAppRefresh()
    }

    func stop() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: getTaskIndentifier())
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension EventBackgroundTask: BackgroundTask {
    func getTaskIndentifier() -> String {
        return BackgroundTaskIndentifier.flushEvents
    }

    func handle(_ task: BGTask) {
        handleAppRefresh(task)
    }
}
#endif
