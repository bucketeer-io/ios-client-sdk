final class EvaluationStorageImpl: EvaluationStorage {

    var currentEvaluationsId: String {
        get {
            return evaluationUserDefaultsDao.currentEvaluationsId
        }
        set {
            evaluationUserDefaultsDao.setCurrentEvaluationsId(value: newValue)
        }
    }

    var featureTag: String {
        get {
            return evaluationUserDefaultsDao.featureTag
        }
        set {
            evaluationUserDefaultsDao.setFeatureTag(value: newValue)
        }
    }

    var evaluatedAt: String {
        get {
            return evaluationUserDefaultsDao.evaluatedAt
        }
        set {
            evaluationUserDefaultsDao.setEvaluatedAt(value: newValue)
        }
    }

    var userAttributesUpdated: Bool {
        get {
            return evaluationUserDefaultsDao.userAttributesUpdated
        }
        set {
            evaluationUserDefaultsDao.setUserAttributesUpdated(value: newValue)
        }
    }

    private let userId: String
    // Expected SQL Dao
    private let evaluationDao: EvaluationDao
    // Expected in-memory cache Dao
    private let evaluationMemCacheDao: EvaluationMemCacheDao
    private let evaluationUserDefaultsDao: EvaluationUserDefaultsDao

    init(
        userId: String,
        evaluationDao: EvaluationDao,
        evaluationMemCacheDao: EvaluationMemCacheDao,
        evaluationUserDefaultsDao: EvaluationUserDefaultsDao
    ) {
        self.userId = userId
        self.evaluationDao = evaluationDao
        self.evaluationUserDefaultsDao = evaluationUserDefaultsDao
        self.evaluationMemCacheDao = evaluationMemCacheDao
        try? refreshCache()
    }

    func get(userId: String) throws -> [Evaluation] {
        evaluationMemCacheDao.get(key: userId) ?? []
    }

    func deleteAllAndInsert(userId: String, evaluations: [Evaluation], evaluatedAt: String) throws {
        try evaluationDao.startTransaction {
            try evaluationDao.deleteAll(userId: userId)
            try evaluationDao.put(userId: userId, evaluations: evaluations)
        }
        // Update cache directly
        evaluationMemCacheDao.set(key: userId, value: evaluations)
        self.evaluatedAt = evaluatedAt
    }

    func update(evaluations: [Evaluation], archivedFeatureIds: [String], evaluatedAt: String) throws -> Bool {
        // 1. Get current data in db
        var activeEvaluationsDict = try evaluationDao.get(userId: userId)
            .reduce([String:Evaluation]()) { (result, evaluation) -> [String:Evaluation] in
                var result = result
                result[evaluation.featureId] = evaluation
                return result
            }
        // 2. Update evaluation with new data
        for evaluation in evaluations {
            activeEvaluationsDict[evaluation.featureId] = evaluation
        }
        // 3. Filter active
        let activeEvaluations = activeEvaluationsDict.values.filter { evaluation in
            !archivedFeatureIds.contains(evaluation.featureId)
        }.map { item in
            item
        }.sorted { evaluation1, evaluation2 in
            evaluation1.featureId < evaluation2.featureId
        }
        // 4. Save to database
        try deleteAllAndInsert(userId: userId, evaluations: activeEvaluations, evaluatedAt: evaluatedAt)
        return evaluations.count > 0 || archivedFeatureIds.count > 0
    }

    // getBy will return the data from the cache to speed up the response time
    func getBy(userId: String, featureId: String) -> Evaluation? {
        return evaluationMemCacheDao.get(key: userId)?.first { evaluation in
            evaluation.featureId == featureId
        } ?? nil
    }

    func refreshCache() throws {
        let evaluationsInDb = try evaluationDao.get(userId: userId)
        evaluationMemCacheDao.set(key: userId, value: evaluationsInDb)
    }

    func setCurrentEvaluationsId(value: String) {
        currentEvaluationsId = value
    }

    func setFeatureTag(value: String) {
        featureTag = value
    }

    func setEvaluatedAt(value: String) {
        evaluatedAt = value
    }

    func setUserAttributesUpdated(value: Bool) {
        userAttributesUpdated = value
    }
}
