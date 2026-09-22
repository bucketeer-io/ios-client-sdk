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

    var currentEvaluationsId: String { get }
    var evaluatedAt: String { get }
    var userAttributesState: UserAttributesState { get }

    @discardableResult func clearUserAttributesUpdated(state: UserAttributesState) -> Bool

    /// Applies an evaluations payload that arrived over the stream (a `put` or `patch`
    /// event), sharing the same storage write path as `fetch`.
    ///
    /// Deliberately does **not** clear the user-attributes-updated flag: only the polling
    /// path (`fetch`) knows its own request actually carried the flag. Clearing it here
    /// would race a `setUserAttributesUpdated()` whose attributes the stream never sent.
    ///
    /// - Parameter shouldNotify: Checked on the main queue immediately before the listener
    ///   callbacks run, so a `stop()`/`destroy()` that happens after the write can still
    ///   suppress callbacks into torn-down app code. The write itself is not rolled back;
    ///   it is still valid cached data. Must be safe to call from the main thread.
    func applyStreamedEvaluations(
        _ response: GetEvaluationsResponse,
        shouldNotify: @escaping () -> Bool)
}

extension EvaluationInteractor {
    func fetch(user: User, completion: ((GetEvaluationsResult) -> Void)?) {
        self.fetch(user: user, timeoutMillis: nil, completion: completion)
    }

    func applyStreamedEvaluations(_ response: GetEvaluationsResponse) {
        applyStreamedEvaluations(response, shouldNotify: { true })
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

    var evaluatedAt: String {
        return evaluationStorage.evaluatedAt
    }

    var userAttributesState: UserAttributesState {
        return evaluationStorage.userAttributesState
    }

    @discardableResult func clearUserAttributesUpdated(state: UserAttributesState) -> Bool {
        return evaluationStorage.clearUserAttributesUpdated(state: state)
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

                // Ordering carries two invariants (ported from the JS SDK's fetch()):
                // - Write BEFORE clear: the response to a `userAttributesUpdated: true`
                //   request carries the re-evaluation that flag asked for, so a failed
                //   write must skip the clear entirely (see the `catch` below) - the flag
                //   survives and the next poll retries.
                // - Clear BEFORE notify: a listener that triggers a nested fetch must
                //   observe the flag already cleared, or the nested call re-sends
                //   `userAttributesUpdated: true` and gets back a redundant snapshot.
                // Streamed data must never clear the flag - only this, the polling path,
                // does. See `applyStreamedEvaluations(_:shouldNotify:)`.
                let shouldNotifyListener: Bool
                do {
                    shouldNotifyListener = try self?.writeEvaluations(response) ?? false
                } catch let error {
                    logger?.error(error)
                    completion?(.failure(error: .init(error: error), featureTag: featureTag))
                    return
                }

                // Clear logic is now encapsulated in `evaluationStorage` via the state snapshot
                self?.evaluationStorage.clearUserAttributesUpdated(state: userAttributesState)

                if shouldNotifyListener {
                    self?.notifyListeners()
                }

                completion?(result)
            case .failure:
                completion?(result)
            }
        }
    }

    func applyStreamedEvaluations(
        _ response: GetEvaluationsResponse,
        shouldNotify: @escaping () -> Bool) {
        let evaluatedAt = response.evaluations.createdAt
        guard Int64(evaluatedAt) != nil else {
            // Without a readable timestamp the storage staleness guard cannot order this
            // payload against what is cached, so applying it could silently rewind the
            // cache. Drop it; the next stream event or poll carries the state again.
            logger?.warn(
                message: "Dropping streamed evaluations: unreadable evaluatedAt \"\(evaluatedAt)\" "
                    + "(userEvaluationsId: \(response.userEvaluationsId))"
            )
            return
        }

        let shouldNotifyListener: Bool
        do {
            shouldNotifyListener = try writeEvaluations(response)
        } catch let error {
            logger?.error(error)
            return
        }

        guard shouldNotifyListener else { return }
        notifyListeners(shouldNotify: shouldNotify)
    }

    /// Writes `response` to storage. Shared by `fetch` (polling) and
    /// `applyStreamedEvaluations` (streaming).
    /// - Returns: `true` when the write landed and changed something. A write the storage
    ///   staleness guard skipped returns `false`, and callers must not notify listeners
    ///   in that case.
    private func writeEvaluations(_ response: GetEvaluationsResponse) throws -> Bool {
        let userEvaluations = response.evaluations
        // https://github.com/bucketeer-io/android-client-sdk/issues/69
        // forceUpdate: a boolean that tells the SDK to delete all the current data and save the latest evaluations from the response
        if userEvaluations.forceUpdate {
            return try evaluationStorage.deleteAllAndInsert(
                evaluationId: response.userEvaluationsId,
                evaluations: userEvaluations.evaluations,
                evaluatedAt: userEvaluations.createdAt
            )
        }
        // 1. Check the evaluation list in the response and upsert them in the DB if the list is not empty
        // 2. Check the list of the feature flags that were archived on the console and delete them from the DB
        return try evaluationStorage.update(
            evaluationId: response.userEvaluationsId,
            evaluations: userEvaluations.evaluations,
            archivedFeatureIds: userEvaluations.archivedFeatureIds,
            evaluatedAt: userEvaluations.createdAt
        )
    }

    /// Calls every registered listener on the main thread.
    /// - Parameter shouldNotify: Checked on the main queue, immediately before the
    ///   listener callbacks run - see the doc comment on the protocol requirement for why.
    private func notifyListeners(shouldNotify: @escaping () -> Bool = { true }) {
        // Update listeners should be called on the main thread
        // to avoid unintentional lock on Interactor's execution thread.
        DispatchQueue.main.async { [weak self] in
            guard shouldNotify() else { return }
            self?.updateListeners.forEach({ _, listener in
                listener.onUpdate()
            })
        }
    }

    func refreshCache() throws {
        try evaluationStorage.refreshCache()
    }

    func setUserAttributesUpdated() {
        // https://github.com/bucketeer-io/android-client-sdk/issues/69
        // userAttributesUpdated: when the user attributes change via the customAttributes interface,
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
