import UIKit

final class TaskScheduler {
    let component: Component
    let dispatchQueue: DispatchQueue

    private lazy var foregroundSchedulers: [ScheduledTask] = [
        EvaluationForegroundTask(component: component, queue: dispatchQueue),
        EventForegroundTask(component: component, queue: dispatchQueue)
    ]

    private lazy var backgroundSchedulers: [ScheduledTask] = {

        guard #available(iOS 13.0, tvOS 13.0, *) else {
            return []
        }
        return [
            EvaluationBackgroundTask(component: component, queue: dispatchQueue),
            EventBackgroundTask(component: component, queue: dispatchQueue)
        ]
    }()

    init(component: Component, dispatchQueue: DispatchQueue) {
        self.component = component
        self.dispatchQueue = dispatchQueue
        if #available(iOS 13.0, tvOS 13.0, *) {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(onForeground),
                name: UIScene.willConnectNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(onForeground),
                name: UIScene.willEnterForegroundNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(onBackground),
                name: UIScene.didEnterBackgroundNotification,
                object: nil
            )
        } else {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(onForeground),
                name: UIApplication.didFinishLaunchingNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(onForeground),
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(onBackground),
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )
        }
    }

    @objc func onForeground() {
        foregroundSchedulers.forEach({ $0.start() })
        backgroundSchedulers.forEach({ $0.stop() })
    }

    @objc func onBackground() {
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
}
