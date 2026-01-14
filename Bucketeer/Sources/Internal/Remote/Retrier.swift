import Foundation

/// Retrier executes asynchronous tasks and handles retries using an exponential backoff strategy.
///
/// - Important: This class is not thread-safe.
/// It is designed to be used serially within the context of the `DispatchQueue` provided at initialization.
/// To ensure thread safety, all calls to public methods (such as `attempt` and `cancel`) must be dispatched on that specific queue.
final class Retrier {

    private static let DEFAULT_BASE_DELAY_SECONDS = 1.0 // in seconds
    private static let DEFAULT_MULTIPLIER = 2.0

    typealias TaskCallback<T> = (Result<T, Error>) -> Void
    typealias Task<T> = (@escaping TaskCallback<T>) -> Void
    typealias Condition = (Error) -> Bool

    private let dispatchQueue: DispatchQueue

    init(queue: DispatchQueue) {
        self.dispatchQueue = queue
    }

    func attempt<T>(
        task: @escaping Task<T>,
        condition: @escaping Condition = { _ in true },
        maxAttempts: Int = 3,
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
        task { [weak self] result in
            // 1. Ensure thread safety: Jump back to the specific queue to access/modify properties
            self?.dispatchQueue.async {
                switch result {
                case .success:
                    completion(result)
                case .failure(let error):
                    // If attempts remain AND condition is met (e.g. 499 or network error)
                    guard remaining > 1, condition(error) else {
                        completion(result)
                        return
                    }
                    // Exponential backoff delay in seconds: 2^retryCount (e.g., 1s before the 1st retry, 2s before the 2nd retry)
                    let attemptsMade = maxAttempts - remaining
                    let nextDelay = pow(Retrier.DEFAULT_MULTIPLIER, Double(attemptsMade)) * Retrier.DEFAULT_BASE_DELAY_SECONDS
                    // Assign to the property so it can be cancelled
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
}
