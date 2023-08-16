import Foundation
#if canImport(BackgroundTasks)
import BackgroundTasks
import SwiftUI

@available(iOS 13.0, tvOS 13.0, *)
public final class BKTBackgroundTask {
    private static var handlerRegistry: [String: BackgroundTask] = [:]
    private static var availableBackgroundTaskIds = [
        BackgroundTaskIndentifier.flushEvents,
        BackgroundTaskIndentifier.fetchEvaluations
    ]

    public static func enable() {
        // Register all background task here
        availableBackgroundTaskIds.forEach { taskId in
            BGTaskScheduler.shared.register(forTaskWithIdentifier: taskId, using: nil) { task in
                forwardTaskToHandler(taskId, task)
            }
        }
    }

    private static func forwardTaskToHandler(_ identifier: String, _ task: BGTask) {
        if let handler = handlerRegistry[identifier] {
            handler.handle(task)
        } else {
            // no handler
            task.setTaskCompleted(success: true)
        }
    }

    static func registerHandler(forTaskWithIdentifier identifier: String, handler: BackgroundTask) {
        handlerRegistry[identifier] = handler
    }

    static func unregisterAllHandler() {
        handlerRegistry.removeAll()
    }
}

@available(iOS 14.0, tvOS 14.0, *)
extension Scene {
    public func enableBKTBackgroundTask() -> some Scene {
        BKTBackgroundTask.enable()
        return self
    }
}
#endif
