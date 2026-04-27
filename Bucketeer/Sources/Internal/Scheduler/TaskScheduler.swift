import UIKit

final class TaskScheduler {
    let component: Component
    let dispatchQueue: DispatchQueue

    private(set) lazy var foregroundSchedulers: [ScheduledTask] = [
        EvaluationForegroundTask(component: component, queue: dispatchQueue),
        EventForegroundTask(component: component, queue: dispatchQueue)
    ]

    private(set) lazy var backgroundSchedulers: [ScheduledTask] = {
        guard #available(iOS 13.0, tvOS 13.0, *) else {
            return []
        }
        let tasks : [BackgroundTask] =  [
            EvaluationBackgroundTask(component: component, queue: dispatchQueue),
            EventBackgroundTask(component: component, queue: dispatchQueue)
        ]
        // Register background task handler when init
        tasks.forEach { bgTask in
            BKTBackgroundTask.registerHandler(forTaskWithIdentifier: bgTask.getTaskIndentifier(), handler: bgTask)
        }
        return tasks
    }()

    deinit {
        if #available(iOS 13.0, tvOS 13.0, *) {
            BKTBackgroundTask.unregisterAllHandler()
        }
    }

    init(component: Component, dispatchQueue: DispatchQueue) {
        self.component = component
        self.dispatchQueue = dispatchQueue

        onForeground()
        if #available(iOS 13.0, tvOS 13.0, *) {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(onForeground),
                name: UIScene.didActivateNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(onBackground),
                name: UIScene.willDeactivateNotification,
                object: nil
            )
        } else {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(onForeground),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(onBackground),
                name: UIApplication.willResignActiveNotification,
                object: nil
            )
        }
    }

    @objc private func onForeground() {
        component.config.logger?.debug(message: "[TaskScheduler]: onForeground")
        foregroundSchedulers.forEach({ $0.start() })
        backgroundSchedulers.forEach({ $0.stop() })
    }

    @objc func onBackground() {
        component.config.logger?.debug(message: "[TaskScheduler]: onBackground")
        foregroundSchedulers.forEach({ $0.stop() })
        // flush events before switching to background tasks
        dispatchQueue.async {
            self.component.eventInteractor.sendEvents(force: true, completion: nil)
        }
        backgroundSchedulers.forEach({ $0.start() })
    }

    func stop() {
        foregroundSchedulers.forEach({ $0.stop() })
        backgroundSchedulers.forEach({ $0.stop() })
    }

    func invalidate() {
        stop()
        foregroundSchedulers.removeAll()
        backgroundSchedulers.removeAll()
    }

    /// The evaluation tasks are disabled by default.
    /// Enables the evaluation tasks (foreground and background) after the initial fetch completes.
    /// Thread-safe — `isTaskEnabled` is protected by NSLock inside each task, so this may be
    /// called from any queue. Typically called from the fetchEvaluations completion in
    /// BKTClient.performInitialFetch.
    func enableEvaluationTask() {
        foregroundSchedulers
            .compactMap { $0 as? EvaluationForegroundTask }
            .first?
            .enable()
        if #available(iOS 13.0, tvOS 13.0, *) {
            backgroundSchedulers
                .compactMap { $0 as? EvaluationBackgroundTask }
                .first?
                .enable()
        }
    }
}
