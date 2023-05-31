import Foundation
@testable import Bucketeer

struct MockEvaluationInteractor: EvaluationInteractor {
    typealias FetchHandler = (_ user: User, _ timeoutMillis: Int64?, _ completion: ((GetEvaluationsResult) -> Void)?) -> Void

    var fetchHandler: FetchHandler?
    var currentEvaluationsId: String = ""

    func fetch(user: User, timeoutMillis: Int64?, completion: ((GetEvaluationsResult) -> Void)?) {
        fetchHandler?(user, timeoutMillis, completion)
    }
    func getLatest(userId: String, featureId: String) -> Evaluation? {
        fatalError()
    }
    func refreshCache(userId: String) throws {
    }
    func clearCurrentEvaluationsId() {
    }
    func addUpdateListener(listener: Bucketeer.EvaluationUpdateListener) -> String {
        return ""
    }

    func removeUpdateListener(key: String) {
    }

    func clearUpdateListeners() {
    }
}
