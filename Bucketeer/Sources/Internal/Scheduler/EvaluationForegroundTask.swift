import Foundation

final class EvaluationForegroundTask: ScheduledTask {
    private weak var component: Component?
    private let queue: DispatchQueue
    private var poller: Poller?
    private var retryPollingInterval: Int64
    private var maxRetryCount: Int

    private var retryCount: Int = 0

    init(component: Component,
         queue: DispatchQueue,
         retryPollingInterval: Int64 = Constant.RETRY_POLLING_INTERVAL,
         maxRetryCount: Int = Constant.MAX_RETRY_COUNT) {

        self.component = component
        self.queue = queue
        self.retryPollingInterval = retryPollingInterval
        self.maxRetryCount = maxRetryCount
    }

    private func reschedule(isRetrying: Bool) {
        self.stop()
        guard let component = component else { return }
        self.poller = .init(
            intervalMillis: isRetrying ? retryPollingInterval : component.config.eventsFlushInterval,
            queue: queue,
            logger: component.config.logger,
            handler: { [weak self] _ in
                self?.fetchEvaluations()
            }
        )
        poller?.start()
    }

    func start() {
        reschedule(isRetrying: false)
    }

    func stop() {
        poller?.stop()
        poller = nil
    }

    private func fetchEvaluations() {
        guard let component = component else { return }
        let eventInteractor = component.eventInteractor
        let retryCount = self.retryCount
        let maxRetryCount = self.maxRetryCount
        let retryPollingInterval = self.retryPollingInterval
        let pollingInterval = component.config.pollingInterval
        component.evaluationInteractor.fetch(user: component.userHolder.user, timeoutMillis: nil) { [weak self] result in
            do {
                switch result {
                case .success(let response):
                    try eventInteractor.trackFetchEvaluationsSuccess(
                        featureTag: response.featureTag,
                        seconds: response.seconds,
                        sizeByte: response.sizeByte
                    )
                    // reset retry count
                    self?.retryCount = 0

                case .failure(let error, let featureTag):
                    try eventInteractor.trackFetchEvaluationsFailure(
                        featureTag: featureTag,
                        error: error
                    )
                    if pollingInterval <= retryPollingInterval {
                        // pollingInterval is short enough, do nothing
                        return
                    }
                    let retried = retryCount > 0
                    let canRetry = retryCount < maxRetryCount
                    if canRetry {
                        // we can retry more
                        self?.retryCount += 1
                        if !retried {
                            self?.reschedule(isRetrying: true)
                        }
                    } else {
                        // we already retried enough, let's get back to daily job
                        self?.retryCount = 0
                        self?.reschedule(isRetrying: false)
                    }
                }
            } catch let error {
                self?.component?.config.logger?.error(error)
            }
        }
    }
}
