import Foundation

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
        delay: TimeInterval = 1.0,
        completion: @escaping TaskCallback<T>
    ) {
        attemptRecursive(
            task: task,
            condition: condition,
            remaining: maxAttempts,
            delay: delay,
            completion: completion
        )
    }

    private func attemptRecursive<T>(
        task: @escaping Task<T>,
        condition: @escaping Condition,
        remaining: Int,
        delay: TimeInterval,
        completion: @escaping TaskCallback<T>
    ) {
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
                // Exponential backoff delay in seconds: 2^retryCount (e.g., 1s before the 1st retry, 2s before the 2nd retry)
                let nextDelay = pow(Retrier.DEFAULT_MULTIPLIER, Double(remaining)) * Retrier.DEFAULT_BASE_DELAY_SECONDS
                self?.dispatchQueue.asyncAfter(deadline: .now() + delay) {
                    self?.attemptRecursive(
                        task: task,
                        condition: condition,
                        remaining: remaining - 1,
                        delay: nextDelay,
                        completion: completion
                    )
                }
            }
        }
    }
}
