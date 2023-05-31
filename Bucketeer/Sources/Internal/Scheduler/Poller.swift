import Foundation

final class Poller {
    private var timer: DispatchSourceTimer?
    private let intervalMillis: Int64
    private let queue: DispatchQueue
    private let logger: Logger?
    private let handler: ((Poller) -> Void)

    var isStarted: Bool {
        timer != nil
    }

    init(intervalMillis: Int64, queue: DispatchQueue, logger: Logger?, handler: @escaping (Poller) -> Void) {
        self.intervalMillis = intervalMillis
        self.handler = handler
        self.queue = queue
        self.logger = logger
    }

    func start() {
        if isStarted {
            logger?.debug(message: "reset poller")
            stop()
        }
        let timer = DispatchSource.makeTimerSource(queue: self.queue)
        timer.schedule(deadline: .now() + .milliseconds(Int(intervalMillis)), repeating: .milliseconds(Int(intervalMillis)))
        timer.setEventHandler(handler: { [weak self] in
            guard let `self` = self else { return }
            self.handler(self)
        })
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }
}
