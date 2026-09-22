import Foundation
@testable import Bucketeer

struct MockEvaluationInteractor: EvaluationInteractor {

    typealias FetchHandler = (_ user: User, _ timeoutMillis: Int64?, _ completion: ((GetEvaluationsResult) -> Void)?) -> Void
    typealias ApplyStreamedEvaluationsHandler = (_ response: GetEvaluationsResponse, _ shouldNotify: @escaping () -> Bool) -> Void

    var fetchHandler: FetchHandler?
    var applyStreamedEvaluationsHandler: ApplyStreamedEvaluationsHandler?
    var currentEvaluationsId: String = ""
    var evaluatedAt: String = "0"
    var userAttributesState: UserAttributesState = UserAttributesState(version: 0, isUpdated: false)

    func fetch(user: User, timeoutMillis: Int64?, completion: ((GetEvaluationsResult) -> Void)?) {
        fetchHandler?(user, timeoutMillis, completion)
    }

    func applyStreamedEvaluations(_ response: GetEvaluationsResponse, shouldNotify: @escaping () -> Bool) {
        applyStreamedEvaluationsHandler?(response, shouldNotify)
    }

    func getLatest(userId: String, featureId: String) -> Evaluation? {
        fatalError()
    }

    func refreshCache() throws {}

    func setUserAttributesUpdated() {}

    @discardableResult func clearUserAttributesUpdated(state: UserAttributesState) -> Bool {
        return false
    }

    func addUpdateListener(listener: Bucketeer.EvaluationUpdateListener) -> String {
        return ""
    }

    func removeUpdateListener(key: String) {}

    func clearUpdateListeners() {}
}
