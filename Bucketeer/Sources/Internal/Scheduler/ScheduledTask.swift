import Foundation

protocol ScheduledTask {
    func register()
    func start()
    func stop()
}

extension ScheduledTask {
    func register() {}
}
