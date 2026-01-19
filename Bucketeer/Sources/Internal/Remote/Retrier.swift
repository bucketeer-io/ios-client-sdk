import Foundation

/// Retrier executes asynchronous tasks and handles retries using an exponential backoff strategy.
///
/// - Important: This class is not thread-safe.
/// It is designed to be used serially within the context of the `DispatchQueue` provided at initialization.
/// To ensure thread safety, all calls to public methods (such as `attempt`) must be dispatched on that specific queue.
final class Retrier {

    private static let DEFAULT_BASE_DELAY_SECONDS = 1.0 // in seconds
    private static let DEFAULT_MULTIPLIER = 2.0

    typealias TaskCallback<T> = (Result<T, Error>) -> Void
    typealias Task<T> = (@escaping TaskCallback<T>) -> Void
    typealias Condition = (Error) -> Bool

    private let dispatchQueue: DispatchQueue

    /// Initializes a new instance of the `Retrier`.
    ///
    /// - Parameter queue: The `DispatchQueue` on which the retries will be scheduled and executed.
    ///                    This queue is also used to ensure serial execution of the retry logic.
    init(queue: DispatchQueue) {
        self.dispatchQueue = queue
    }

    /// Attempts to execute an asynchronous task with a specified retry policy.
    ///
    /// This method will execute the provided `task` immediately. If the task fails and the `condition` returns `true`,
    /// it will retry the task up to `maxAttempts - 1` times using an exponential backoff strategy.
    ///
    /// The delay between retries is calculated as: `2^attemptsMade * 1.0` seconds.
    ///
    /// - Parameters:
    ///   - task: The asynchronous task to be executed. It accepts a completion handler that must be called with a `Result`.
    ///           The task closure should be dispatched on the same queue as the Retrier instance to ensure thread safety.
    ///   - condition: A closure that determines whether a retry should be attempted based on the error received.
    ///                Defaults to retrying on any error.
    ///   - maxAttempts: The maximum number of times the task will be attempted (initial attempt + retries).
    ///
    ///   - completion: The completion handler to be called when the task succeeds or when all retry attempts fail.
    func attempt<T>(
        task: @escaping Task<T>,
        condition: @escaping Condition,
        maxAttempts: Int,
        completion: @escaping TaskCallback<T>
    ) {
        attemptRecursive(
            task: task,
            condition: condition,
            remaining: maxAttempts,
            maxAttempts: maxAttempts,
            completion: completion
        )
    }

    private func attemptRecursive<T>(
        task: @escaping Task<T>,
        condition: @escaping Condition,
        remaining: Int,
        maxAttempts: Int,
        completion: @escaping TaskCallback<T>
    ) {
        // weak self - we don't want to retain self in case the Retrier is deallocated
        // if self is deallocated, no further retries will be attempted
        task { [weak self] result in
            switch result {
            case .success:
                completion(result)
            case .failure(let error):
                // If attempts remain AND condition is met (e.g. 499 or network error)
                guard remaining > 1, condition(error) else {
                    completion(result)
                    return
                }
                // Exponential backoff delay = baseDelay * multiplier^attemptsMade (defaults yield 2s, 4s, 8s, ...)
                let attemptsMade = maxAttempts - remaining
                let nextDelay = pow(Retrier.DEFAULT_MULTIPLIER, Double(attemptsMade)) * Retrier.DEFAULT_BASE_DELAY_SECONDS
                self?.dispatchQueue.asyncAfter(deadline: .now() + nextDelay, execute: {
                    self?.attemptRecursive(
                        task: task,
                        condition: condition,
                        remaining: remaining - 1,
                        maxAttempts: maxAttempts,
                        completion: completion
                    )
                })
            }
        }
    }
}
