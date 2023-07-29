import Foundation
@testable import Bucketeer

// swiftlint:disable large_tuple
typealias GetEvaluationsHandler = ((User, String, Int64?, UserEvaluationCondition, ((GetEvaluationsResult) -> Void)?)) -> Void
typealias RegisterEventsHandler = ([Event], ((Result<RegisterEventsResponse, BKTError>) -> Void)?) -> Void

// MockApiClient: this mock will return the result immediately
final class MockApiClient: ApiClient {
    let getEvaluationsHandler: GetEvaluationsHandler?
    let registerEventsHandler: RegisterEventsHandler?

    init(getEvaluationsHandler: GetEvaluationsHandler? = nil,
         registerEventsHandler: RegisterEventsHandler? = nil) {

        self.getEvaluationsHandler = getEvaluationsHandler
        self.registerEventsHandler = registerEventsHandler
    }

    func getEvaluations(
        user: Bucketeer.User,
        userEvaluationsId: String,
        timeoutMillis: Int64?,
        condition: UserEvaluationCondition,
        completion: ((Bucketeer.GetEvaluationsResult) -> Void)?) {
        getEvaluationsHandler?((user, userEvaluationsId, timeoutMillis, condition, completion))
    }

    func registerEvents(events: [Event], completion: ((Result<RegisterEventsResponse, BKTError>) -> Void)?) {
        registerEventsHandler?(events, completion)
    }
}

// MockApiClient: this mock will run synchronized, blocking the current thread.
// It will get unlock after 3s from a `fake networkQueue` queue
final class MockSynchronizedApiClient: ApiClient {
    let getEvaluationsHandler: GetEvaluationsHandler?
    let registerEventsHandler: RegisterEventsHandler?
    let networkQueue = DispatchQueue(label: "io.bucketeer.concurrentQueue.network", attributes: .concurrent)
    let semaphore = DispatchSemaphore(value: 0)

    deinit {
        semaphore.signal()
    }

    init(getEvaluationsHandler: GetEvaluationsHandler? = nil,
         registerEventsHandler: RegisterEventsHandler? = nil) {
        self.getEvaluationsHandler = getEvaluationsHandler
        self.registerEventsHandler = registerEventsHandler
    }

    func getEvaluations(user: User, userEvaluationsId: String, timeoutMillis: Int64?, condition: UserEvaluationCondition, completion: ((GetEvaluationsResult) -> Void)?) {
        networkQueue.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.semaphore.signal()
            debugPrint("getEvaluations unlocked")
        }
        debugPrint("getEvaluations wait")
        semaphore.wait()
        getEvaluationsHandler?((user, userEvaluationsId, timeoutMillis, condition, completion))
    }

    func registerEvents(events: [Event], completion: ((Result<RegisterEventsResponse, BKTError>) -> Void)?) {
        networkQueue.asyncAfter(deadline: .now() + 3) { [weak self] in
            debugPrint("registerEvents unlocked")
            self?.semaphore.signal()
        }
        debugPrint("registerEvents wait")
        semaphore.wait()
        registerEventsHandler?(events, completion)
    }
}

// swiftlint:enable large_tuple
