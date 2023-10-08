final class EvaluationStorageImpl: EvaluationStorage {

    var currentEvaluationsId: String {
        get {
            return evaluationUserDefaultsDao.currentEvaluationsId
        }
    }

    var featureTag: String {
        get {
            return evaluationUserDefaultsDao.featureTag
        }
    }

    var evaluatedAt: String {
        get {
            return evaluationUserDefaultsDao.evaluatedAt
        }
    }

    var userAttributesUpdated: Bool {
        get {
            return evaluationUserDefaultsDao.userAttributesUpdated
        }
    }

    private let userId: String
    // Expected SQL Dao
    private let evaluationSQLDao: EvaluationSQLDao
    // Expected in-memory cache Dao
    private let evaluationMemCacheDao: EvaluationMemCacheDao
    private let evaluationUserDefaultsDao: EvaluationUserDefaultsDao

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
        evaluationMemCacheDao.get(key: userId) ?? []
    }

    func deleteAllAndInsert(
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
        try deleteAllAndInsert(
            evaluationId: evaluationId ,
            evaluations: currentEvaluations,
            evaluatedAt: evaluatedAt)
        return evaluations.count > 0 || archivedFeatureIds.count > 0
    }

    // getBy will return the data from the cache to speed up the response time
    func getBy(featureId: String) -> Evaluation? {
        return evaluationMemCacheDao.get(key: userId)?.first { evaluation in
            evaluation.featureId == featureId
        } ?? nil
    }

    func refreshCache() throws {
        let evaluationsInDb = try evaluationSQLDao.get(userId: userId)
        evaluationMemCacheDao.set(key: userId, value: evaluationsInDb)
    }

    func clearCurrentEvaluationsId() {
        evaluationUserDefaultsDao.setCurrentEvaluationsId(value: "")
    }

    func setFeatureTag(value: String) {
        evaluationUserDefaultsDao.setFeatureTag(value: value)
    }

    func setUserAttributesUpdated() {
        evaluationUserDefaultsDao.setUserAttributesUpdated(value: true)
    }

    func clearUserAttributesUpdated() {
        evaluationUserDefaultsDao.setUserAttributesUpdated(value: false)
    }
}
