final class EvaluationStorageImpl: EvaluationStorage {

    var currentEvaluationsId: String {
        return evaluationUserDefaultsDao.currentEvaluationsId
    }

    var featureTag: String {
        return evaluationUserDefaultsDao.featureTag
    }

    var evaluatedAt: String {
        return evaluationUserDefaultsDao.evaluatedAt
    }

    var userAttributesUpdated: Bool {
        return evaluationUserDefaultsDao.userAttributesUpdated
    }

    private let userId: String
    // Expected SQL Dao
    private let evaluationSQLDao: EvaluationSQLDao
    // Expected in-memory cache Dao
    private let evaluationMemCacheDao: EvaluationMemCacheDao
    private let evaluationUserDefaultsDao: EvaluationUserDefaultsDao
    private let lock = NSLock()

    init(
        userId: String,
        evaluationDao: EvaluationSQLDao,
        evaluationMemCacheDao: EvaluationMemCacheDao,
        evaluationUserDefaultsDao: EvaluationUserDefaultsDao
    ) {
        self.userId = userId
        self.evaluationSQLDao = evaluationDao
        self.evaluationUserDefaultsDao = evaluationUserDefaultsDao
        self.evaluationMemCacheDao = evaluationMemCacheDao
        try? refreshCache()
    }

    func get() throws -> [Evaluation] {
        return lock.withLock {
            evaluationMemCacheDao.get(key: userId) ?? []
        }
    }

    func deleteAllAndInsert(
        evaluationId: String,
        evaluations: [Evaluation],
        evaluatedAt: String) throws {
            try lock.withLock {
                try forceUpdate(
                    evaluationId: evaluationId,
                    evaluations: evaluations,
                    evaluatedAt: evaluatedAt
                )
            }
        }

    private func forceUpdate(
        evaluationId: String,
        evaluations: [Evaluation],
        evaluatedAt: String) throws {
            try evaluationSQLDao.startTransaction {
                try evaluationSQLDao.deleteAll(userId: userId)
                try evaluationSQLDao.put(evaluations: evaluations)
            }

            evaluationUserDefaultsDao.setEvaluatedAt(value: evaluatedAt)
            evaluationUserDefaultsDao.setCurrentEvaluationsId(value: evaluationId)
            // Update cache directly
            evaluationMemCacheDao.set(key: userId, value: evaluations)
        }

    func update(
        evaluationId: String ,
        evaluations: [Evaluation],
        archivedFeatureIds: [String],
        evaluatedAt: String) throws -> Bool {
            try lock.withLock {
                // 1. Get current data in db
                var currentEvaluationsByFeatureId = try evaluationSQLDao.get(userId: userId)
                    .reduce([String:Evaluation]()) { (input, evaluation) -> [String:Evaluation] in
                        var output = input
                        output[evaluation.featureId] = evaluation
                        return output
                    }
                // 2. Update evaluation with new data
                for evaluation in evaluations {
                    currentEvaluationsByFeatureId[evaluation.featureId] = evaluation
                }
                // 3. Filter active
                let currentEvaluations = currentEvaluationsByFeatureId.values.filter { evaluation in
                    !archivedFeatureIds.contains(evaluation.featureId)
                }.map { item in
                    item
                }
                // 4. Save to database
                try forceUpdate(
                    evaluationId: evaluationId ,
                    evaluations: currentEvaluations,
                    evaluatedAt: evaluatedAt)
                return evaluations.count > 0 || archivedFeatureIds.count > 0
            }
        }

    // getBy will return the data from the cache to speed up the response time
    func getBy(featureId: String) -> Evaluation? {
        return lock.withLock {
            return evaluationMemCacheDao.get(key: userId)?.first { evaluation in
                evaluation.featureId == featureId
            } ?? nil
        }
    }

    func refreshCache() throws {
        try lock.withLock {
            let evaluationsInDb = try evaluationSQLDao.get(userId: userId)
            evaluationMemCacheDao.set(key: userId, value: evaluationsInDb)
        }
    }

    func clearCurrentEvaluationsId() {
        lock.withLock {
            evaluationUserDefaultsDao.setCurrentEvaluationsId(value: "")
        }
    }

    func setFeatureTag(value: String) {
        lock.withLock {
            evaluationUserDefaultsDao.setFeatureTag(value: value)
        }
    }

    func setUserAttributesUpdated() {
        lock.withLock {
            evaluationUserDefaultsDao.setUserAttributesUpdated(value: true)
        }
    }

    func clearUserAttributesUpdated() {
        lock.withLock {
            evaluationUserDefaultsDao.setUserAttributesUpdated(value: false)
        }
    }
}
