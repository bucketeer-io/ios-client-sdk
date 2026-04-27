import Foundation

final class EvaluationForegroundTask: ScheduledTask {
    private let component: Component
    private let queue: DispatchQueue
    private var poller: Poller?
    private var retryPollingInterval: Int64
    private var maxRetryCount: Int

    private var retryCount: Int = 0

    // MARK: - Thread Safety
    // `isTaskEnabled` can be read from the poller queue and written from any caller queue
    // (e.g. main thread via performInitialFetch or fetchEvaluations completion).
    // We protect it with NSLock instead of relying on queue confinement, so callers
    // do not need to be on a specific queue.
    private let lock = NSLock()
    private var _isTaskEnabled: Bool

    /// Thread-safe read of the enabled flag.
    var isTaskEnabled: Bool { lock.withLock { _isTaskEnabled } }

    init(component: Component,
         queue: DispatchQueue,
         retryPollingInterval: Int64 = Constant.RETRY_POLLING_INTERVAL,
         maxRetryCount: Int = Constant.MAX_RETRY_COUNT,
         enabled: Bool = false) {

        self.component = component
        self.queue = queue
        self.retryPollingInterval = retryPollingInterval
        self.maxRetryCount = maxRetryCount
        _isTaskEnabled = enabled
    }

    /// Enables the task so the next poller tick will execute a fetch.
    /// Thread-safe — may be called from any queue.
    func enable() {
        lock.withLock { _isTaskEnabled = true }
    }

    private func reschedule(interval: Int64) {
        self.stop()
        self.poller = .init(
            intervalMillis: interval,
            queue: queue,
            logger: component.config.logger,
            handler: { [weak self] _ in
                self?.queue.async {
                    self?.fetchEvaluations()
                }
            }
        )
        poller?.start()
    }

    func start() {
        reschedule(interval: self.component.config.pollingInterval)
    }

    func stop() {
        poller?.stop()
        poller = nil
    }

    private func fetchEvaluations() {
        let eventInteractor = component.eventInteractor
        let retryCount = self.retryCount
        let maxRetryCount = self.maxRetryCount
        let retryPollingInterval = self.retryPollingInterval
        let pollingInterval = component.config.pollingInterval

        guard isTaskEnabled else {
            // if the task is not enabled, we don't want to fetch evaluations and
            // we reset the retry count and reschedule it to use the default polling interval configured in the BKTConfig
            component.config.logger?.debug(message: "[EvaluationForegroundTask] Task not enabled, skipping")
            self.retryCount = 0
            self.reschedule(interval: pollingInterval)
            return
        }

        component.evaluationInteractor.fetch(user: component.userHolder.user, timeoutMillis: nil) { [weak self] result in
            do {
                switch result {
                case .success(let response):
                    try eventInteractor.trackFetchEvaluationsSuccess(
                        featureTag: response.featureTag,
                        seconds: response.seconds,
                        sizeByte: response.sizeByte
                    )
                    // reset the scheduler to use the default polling interval configured in the BKTConfig
                    if (retryCount > 0) {
                        self?.retryCount = 0
                        self?.reschedule(interval: pollingInterval)
                    }

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
                            // we reschedule just once and wait until it reaches
                            // the max retrying count or succeeds to reschedule it again
                            // to use the default polling interval configured in the BKTConfig
                            self?.reschedule(interval: retryPollingInterval)
                        }
                    } else {
                        // we already retried enough, let's get back to daily job
                        self?.retryCount = 0
                        self?.reschedule(interval: pollingInterval)
                    }
                }
            } catch let error {
                self?.component.config.logger?.error(error)
            }
        }
    }
}
