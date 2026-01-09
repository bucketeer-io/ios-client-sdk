import Foundation

protocol EvaluationInteractor {
    func fetch(user: User, timeoutMillis: Int64?, completion: ((GetEvaluationsResult) -> Void)?)
    func getLatest(userId: String, featureId: String) -> Evaluation?
    func refreshCache() throws
    func setUserAttributesUpdated()
    @discardableResult
    func addUpdateListener(listener: EvaluationUpdateListener) -> String
    func removeUpdateListener(key: String)
    func clearUpdateListeners()
}

extension EvaluationInteractor {
    func fetch(user: User, completion: ((GetEvaluationsResult) -> Void)?) {
        self.fetch(user: user, timeoutMillis: nil, completion: completion)
    }
}

final class EvaluationInteractorImpl: EvaluationInteractor {

    private let apiClient: ApiClient
    private let idGenerator: IdGenerator
    private let logger: Logger?
    private let evaluationStorage: EvaluationStorage

    init(apiClient: ApiClient,
         evaluationStorage: EvaluationStorage,
         idGenerator: IdGenerator,
         featureTag: String,
         logger: Logger? = nil) {
        self.apiClient = apiClient
        self.evaluationStorage = evaluationStorage

        self.idGenerator = idGenerator
        self.logger = logger
        updateFeatureTag(value: featureTag)
    }

    private var updateListeners: [String: EvaluationUpdateListener] = [:]

    var currentEvaluationsId: String {
        return evaluationStorage.currentEvaluationsId
    }

    func fetch(user: User, timeoutMillis: Int64?, completion: ((GetEvaluationsResult) -> Void)?) {

        let logger = self.logger
        let evaluatedAt = evaluationStorage.evaluatedAt
        let userAttributesState = evaluationStorage.userAttributesState
        let userAttributesUpdated = userAttributesState.isUpdated
        let currentEvaluationsId = evaluationStorage.currentEvaluationsId
        let featureTag = evaluationStorage.featureTag

        apiClient.getEvaluations(
            user: user,
            userEvaluationsId: currentEvaluationsId,
            timeoutMillis: timeoutMillis,
            condition: UserEvaluationCondition(
                evaluatedAt: evaluatedAt,
                userAttributesUpdated: userAttributesUpdated)) { [weak self] result in
            switch result {
            case .success(let response):
                let newEvaluationsId = response.userEvaluationsId
                if currentEvaluationsId == newEvaluationsId {
                    logger?.debug(message: "Nothing to sync")
                    // Clear logic is now encapsulated in `evaluationStorage` via the state snapshot
                    self?.evaluationStorage.clearUserAttributesUpdated(state: userAttributesState)
                    completion?(result)
                    return
                }

                let newEvaluations = response.evaluations.evaluations
                let evaluatedAt = response.evaluations.createdAt
                let forceUpdate = response.evaluations.forceUpdate
                var shouldNotifyListener = true
                do {
                    // https://github.com/bucketeer-io/android-client-sdk/issues/69
                    // forceUpdate: a boolean that tells the SDK to delete all the current data and save the latest evaluations from the response
                    if forceUpdate {
                        try self?.evaluationStorage.deleteAllAndInsert(
                            evaluationId: newEvaluationsId,
                            evaluations: response.evaluations.evaluations,
                            evaluatedAt: evaluatedAt
                        )
                    } else {
                        // 1. Check the evaluation list in the response and upsert them in the DB if the list is not empty
                        // 2. Check the list of the feature flags that were archived on the console and delete them from the DB
                        shouldNotifyListener = try self?.evaluationStorage.update(
                            evaluationId: newEvaluationsId,
                            evaluations: newEvaluations,
                            archivedFeatureIds: response.evaluations.archivedFeatureIds,
                            evaluatedAt: evaluatedAt
                        ) ?? false
                    }
                } catch let error {
                    logger?.error(error)
                    completion?(.failure(error: .init(error: error), featureTag: featureTag))
                    return
                }

                // Clear logic is now encapsulated in `evaluationStorage` via the state snapshot
                self?.evaluationStorage.clearUserAttributesUpdated(state: userAttributesState)

                if shouldNotifyListener {
                    // Update listeners should be called on the main thread
                    // to avoid unintentional lock on Interactor's execution thread.
                    DispatchQueue.main.async {
                        self?.updateListeners.forEach({ _, listener in
                            listener.onUpdate()
                        })
                    }
                }

                completion?(result)
            case .failure:
                completion?(result)
            }
        }
    }

    func refreshCache() throws {
        try evaluationStorage.refreshCache()
    }

    /*
     Note: Logical race condition on `userAttributesUpdated`

     Problem:
     - `userAttributesUpdated` is a boolean that only indicates "there exists at least one pending attribute change".
     - If the flag is already `true` when a fetch starts, and attributes are updated again while the request is in-flight, the fetch cannot distinguish the new update from the old one.
     - The fetch may clear the flag on completion (because it saw `true` at start), causing any updates that happened during the request to be lost.

     Example (double-update):
     1) flag = true
     2) fetch starts and reads true
     3) attributes updated again (flag remains true)
     4) fetch completes and clears flag
     5) the second update is never sent

     Conclusion:
     A single boolean cannot represent "which" update was sent; clearing it after a fetch can discard concurrent updates.
     
     Solution: Use a version number to track the state of user attributes updates.
     Each update increments the version, and clearing only happens if the version matches
     ensuring concurrent updates are not lost.
    */
    func setUserAttributesUpdated() {
        // https://github.com/bucketeer-io/android-client-sdk/issues/69
        // userAttributesUpdated: when the user attributes change via the customAttributes interface,
        // the userAttributesUpdated field must be set to true in the next request.
        evaluationStorage.setUserAttributesUpdated()
    }

    func getLatest(userId: String, featureId: String) -> Evaluation? {
        return evaluationStorage.getBy(featureId: featureId)
    }

    func addUpdateListener(listener: EvaluationUpdateListener) -> String {
        let key = idGenerator.id()
        updateListeners[key] = listener
        return key
    }

    func removeUpdateListener(key: String) {
        updateListeners.removeValue(forKey: key)
    }

    func clearUpdateListeners() {
        updateListeners.removeAll()
    }

    private func updateFeatureTag(value: String) {
        // https://github.com/bucketeer-io/android-client-sdk/issues/69
        // 1- Save the featureTag in the UserDefault configured in the BKTConfig
        // 2- Clear the userEvaluationsID in the UserDefault if the featureTag changes
        let featureTag = evaluationStorage.featureTag
        if value != featureTag {
            evaluationStorage.clearCurrentEvaluationsId()
        }
        evaluationStorage.setFeatureTag(value: value)
    }
}
