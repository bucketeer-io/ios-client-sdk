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

    var userAttributesUpdatedVersion: Int {
        return setUserAttributesUpdatedLock.withLock {
            return _userAttributesUpdatedVersion
        }
    }

    private let userId: String
    private let evaluationSQLDao: EvaluationSQLDao
    private let evaluationMemCacheDao: EvaluationMemCacheDao
    private let evaluationUserDefaultsDao: EvaluationUserDefaultsDao

    private var _userAttributesUpdatedVersion: Int = 0
    private let setUserAttributesUpdatedLock = NSLock()

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
        // evaluationMemCacheDao is thread-safe (uses internal concurrent queue).
        // We rely on it without adding extra locks because this storage layer is also accessed serially via the SDK queue.
        //
        // We access the memory cache directly without waiting for pending database writes.
        // If we enforced strict consistency (locking during Disk I/O with SQL), this method would block the calling thread (often the Main Thread), causing UI freezes.
        // This behavior prioritizes application responsiveness, accepting momentary data staleness during background updates.
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
        setUserAttributesUpdatedLock.withLock {
            // Increment version on every update
            _userAttributesUpdatedVersion += 1
            evaluationUserDefaultsDao.setUserAttributesUpdated(value: true)
        }
    }

    // Called from SDK queue (fetch callback)
    func clearUserAttributesUpdated(version: Int) {
        setUserAttributesUpdatedLock.withLock {
            // Only clear if the version matches what we captured at the start of the request.
            // If _userAttributesUpdatedVersion > version, it means a new update happened
            // while the request was in-flight, so we MUST NOT clear the flag.
            if _userAttributesUpdatedVersion == version {
                evaluationUserDefaultsDao.setUserAttributesUpdated(value: false)
            }
        }
    }
}
