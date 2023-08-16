import Foundation
#if canImport(BackgroundTasks)
import BackgroundTasks

@available(iOS 13.0, tvOS 13.0, *)
protocol BackgroundTask: ScheduledTask {
    func getTaskIndentifier() -> String
    func handle(_ task: BGTask)
}
#endif
