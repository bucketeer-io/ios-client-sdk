import Foundation

#if canImport(BackgroundTasks)
import BackgroundTasks

@available(iOS 13.0, tvOS 13.0, *)
final class EvaluationBackgroundTask {
    static let taskId = "io.bucketeer.evaluation.refresh"

    private weak var component: Component?
    private let queue: DispatchQueue

    init(component: Component, queue: DispatchQueue) {
        self.component = component
        self.queue = queue
    }

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskId, using: nil) { task in
            self.handleAppRefresh(task: task as? BGAppRefreshTask)
        }
    }

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskId)
        let interval: TimeInterval = TimeInterval(component?.config.backgroundPollingInterval ?? Constant.DEFAULT_BACKGROUND_POLLING_INTERVAL_MILLIS)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval / 1000)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            component?.config.logger?.error(error)
        }
    }

    func handleAppRefresh(task: BGAppRefreshTask?) {
        // Schedule a new refresh task.
        scheduleAppRefresh()

        guard let component = self.component else { return }
        BKTClient.fetchEvaluationsSync(
            component: component,
            dispatchQueue: queue,
            timeoutMillis: nil,
            completion: { error in
                task?.setTaskCompleted(success: error == nil)
            }
        )
        // Provide the background task with an expiration handler that cancels the operation.
        task?.expirationHandler = { [weak self] in
            self?.component?.config.logger?.warn(message: "The background task is expired.")
        }
    }
}

@available(iOS 13.0, tvOS 13.0, *)
extension EvaluationBackgroundTask: ScheduledTask {
    func start() {
        scheduleAppRefresh()
    }

    func stop() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskId)
    }
}

#endif
