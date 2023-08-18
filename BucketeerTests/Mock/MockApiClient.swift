import Foundation
@testable import Bucketeer

// swiftlint:disable large_tuple
final class MockApiClient: ApiClient {
    typealias GetEvaluationsHandler = ((User, String, Int64?, ((GetEvaluationsResult) -> Void)?)) -> Void
    typealias RegisterEventsHandler = ([Event], ((Result<RegisterEventsResponse, BKTError>) -> Void)?) -> Void

    let getEvaluationsHandler: GetEvaluationsHandler?
    let registerEventsHandler: RegisterEventsHandler?

    init(getEvaluationsHandler: GetEvaluationsHandler? = nil,
         registerEventsHandler: RegisterEventsHandler? = nil) {

        self.getEvaluationsHandler = getEvaluationsHandler
        self.registerEventsHandler = registerEventsHandler
    }

    func getEvaluations(user: User, userEvaluationsId: String, timeoutMillis: Int64?, completion: ((GetEvaluationsResult) -> Void)?) {
        getEvaluationsHandler?((user, userEvaluationsId, timeoutMillis, completion))
    }

    func registerEvents(events: [Event], completion: ((Result<RegisterEventsResponse, BKTError>) -> Void)?) {
        registerEventsHandler?(events, completion)
    }
}

final class MockSynchronizedApiClient: ApiClient {
    typealias GetEvaluationsHandler = ((User, String, Int64?, ((GetEvaluationsResult) -> Void)?)) -> Void
    typealias RegisterEventsHandler = ([Event], ((Result<RegisterEventsResponse, BKTError>) -> Void)?) -> Void

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

    func getEvaluations(user: User, userEvaluationsId: String, timeoutMillis: Int64?, completion: ((GetEvaluationsResult) -> Void)?) {
        networkQueue.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.semaphore.signal()
            debugPrint("getEvaluations unlocked")
        }
        debugPrint("getEvaluations wait")
        semaphore.wait()
        getEvaluationsHandler?((user, userEvaluationsId, timeoutMillis, completion))
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
