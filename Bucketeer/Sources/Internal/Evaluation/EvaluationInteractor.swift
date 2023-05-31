import Foundation

protocol EvaluationInteractor {
    func fetch(user: User, timeoutMillis: Int64?, completion: ((GetEvaluationsResult) -> Void)?)
    func getLatest(userId: String, featureId: String) -> Evaluation?
    func refreshCache(userId: String) throws
    func clearCurrentEvaluationsId()
    @discardableResult
    func addUpdateListener(listener: EvaluationUpdateListener) -> String
    func removeUpdateListener(key: String)
    func clearUpdateListeners()

    var currentEvaluationsId: String { get }
}

extension EvaluationInteractor {
    func fetch(user: User, completion: ((GetEvaluationsResult) -> Void)?) {
        self.fetch(user: user, timeoutMillis: nil, completion: completion)
    }
}

final class EvaluationInteractorImpl: EvaluationInteractor {

    private static let userEvaluationsIdKey = "bucketeer_user_evaluations_id"

    let apiClient: ApiClient
    let evaluationDao: EvaluationDao
    let defaults: Defaults
    let idGenerator: IdGenerator
    let featureTag: String
    let logger: Logger?

    init(apiClient: ApiClient, evaluationDao: EvaluationDao, defaults: Defaults, idGenerator: IdGenerator, featureTag: String, logger: Logger? = nil) {
        self.apiClient = apiClient
        self.evaluationDao = evaluationDao
        self.defaults = defaults
        self.idGenerator = idGenerator
        self.featureTag = featureTag
        self.logger = logger
    }

    // key: userId
    var evaluations: [String: [Evaluation]] = [:]
    var currentEvaluationsId: String {
        get {
            return defaults.string(forKey: Self.userEvaluationsIdKey) ?? ""
        }
        set {
            defaults.set(newValue, forKey: Self.userEvaluationsIdKey)
        }
    }
    var updateListeners: [String: EvaluationUpdateListener] = [:]

    func fetch(user: User, timeoutMillis: Int64?, completion: ((GetEvaluationsResult) -> Void)?) {
        let currentEvaluationsId = self.currentEvaluationsId
        let evaluationDao = self.evaluationDao
        let logger = self.logger
        let featureTag = self.featureTag
        apiClient.getEvaluations(
            user: user,
            userEvaluationsId: currentEvaluationsId,
            timeoutMillis: timeoutMillis) { [weak self] result in
                switch result {
                case .success(let response):
                    let newEvaluationsId = response.userEvaluationsId
                    if currentEvaluationsId == newEvaluationsId {
                        logger?.debug(message: "Nothing to sync")
                        completion?(result)
                        return
                    }
                    let newEvaluations = response.evaluations.evaluations
                    do {
                        try evaluationDao.deleteAllAndInsert(userId: user.id, evaluations: newEvaluations)
                    } catch let error {
                        logger?.error(error)
                        completion?(.failure(error: .init(error: error), featureTag: featureTag))
                        return
                    }
                    self?.currentEvaluationsId = newEvaluationsId
                    self?.evaluations[user.id] = newEvaluations

                    // Update listeners should be called on the main thread
                    // to avoid unintentional lock on Interactor's execution thread.
                    DispatchQueue.main.async {
                        self?.updateListeners.forEach({ _, listener in
                            listener.onUpdate()
                        })
                    }

                    completion?(result)
                case .failure:
                    completion?(result)
                }
        }
    }

    func refreshCache(userId: String) throws {
        evaluations[userId] = try evaluationDao.get(userId: userId)
    }

    func clearCurrentEvaluationsId() {
        currentEvaluationsId = ""
    }

    func getLatest(userId: String, featureId: String) -> Evaluation? {
        let evaluations = evaluations[userId] ?? []
        return evaluations.first(where: { $0.featureId == featureId })
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
}
