import Foundation

final class EventForegroundTask {
    private var poller: Poller?
    private weak var component: Component?
    private let queue: DispatchQueue

    init(component: Component?, queue: DispatchQueue) {
        self.component = component
        self.queue = queue
    }

    private func reschedule() {
        poller?.stop()
        guard let component = component else { return }
        poller = .init(
            intervalMillis: component.config.eventsFlushInterval,
            queue: queue,
            logger: component.config.logger,
            handler: { [weak self] _ in
                self?.component?.eventInteractor.sendEvents(force: true, completion: nil)
            }
        )
        poller?.start()
    }
}

extension EventForegroundTask: ScheduledTask {
    func start() {
        component?.eventInteractor.set(eventUpdateListener: self)
        reschedule()
    }

    func stop() {
        component?.eventInteractor.set(eventUpdateListener: nil)
        poller?.stop()
        poller = nil
    }
}

extension EventForegroundTask: EventUpdateListener {
    func onUpdate(events: [Event]) {
        component?.eventInteractor.sendEvents(force: false) { [weak self] result in
            guard case .success(let success) = result, success else {
                return
            }
            self?.reschedule()
        }
    }
}
