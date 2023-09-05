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
        // Update cache directly after we have force update
        evaluationMemCacheDao.set(key: userId, value: evaluations)
        self.evaluatedAt = evaluatedAt
    }

    func update(evaluations: [Evaluation], archivedFeatureIds: [String], evaluatedAt: String) throws -> Bool {
        var activeEvaluations = [Evaluation]()
        var archivedEvaluationIds = [String]()
        try evaluationDao.startTransaction {
            // 1. Update evaluation with new data
            try evaluationDao.put(userId: userId, evaluations: evaluations)
            // 2. Get current data in db
            let evaluationsInDb = try evaluationDao.get(userId: userId)
            // 3. Filter active & archived
            for evaluation in evaluationsInDb {
                if archivedFeatureIds.contains(evaluation.featureId) {
                    archivedEvaluationIds.append(evaluation.id)
                } else {
                    activeEvaluations.append(evaluation)
                }
            }
            // 4. Remove all the evaluations which have the same id in the list archivedEvaluationIds
            if (archivedEvaluationIds.count > 0) {
                try evaluationDao.deleteByIds(archivedEvaluationIds)
            }
        }
        self.evaluatedAt = evaluatedAt
        // 5. Save a new cache
        evaluationMemCacheDao.set(key: userId, value: activeEvaluations)
        return evaluations.count > 0 || archivedEvaluationIds.count > 0
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
