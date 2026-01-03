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
    private let evaluationSQLDao: EvaluationSQLDao
    private let evaluationMemCacheDao: EvaluationMemCacheDao
    // UserDefaults is thread-safe by design, no additional locking needed
    private let evaluationUserDefaultsDao: EvaluationUserDefaultsDao
    
    // IMPORTANT: Why lock at Storage layer instead of InMemoryCache?
    //
    // Threading Model:
    // - WRITES (deleteAllAndInsert/update): Always run on SDK's serial dispatchQueue
    //   (via BKTClient.execute {} in line 238-248 of BKTClient.swift)
    // - READS (getBy): Called directly from main thread in BKTClient.getBKTEvaluationDetails()
    //   (line 17 of BKTClient.swift) -> NO execute {} wrapper!
    //
    // Lock Protects TWO Critical Aspects:
    //
    // 1. Thread-safety for concurrent read-write access to evaluationMemCacheDao (Dictionary)
    //    - Main thread reads via getBy() -> evaluationMemCacheDao.get()
    //    - SDK queue writes via update()/deleteAllAndInsert() -> evaluationMemCacheDao.set()
    //    - Swift Dictionary is NOT thread-safe for concurrent read-write operations!
    //    - Race condition: Main thread reading while SDK queue is writing would cause crashes or data corruption
    //
    // 2. Atomicity of compound operations (SQL + UserDefaults + Cache)
    //    Example: forceUpdate() must be atomic:
    //      a. SQL: delete all + insert new (in transaction)
    //      b. UserDefaults: update evaluatedAt + currentEvaluationsId
    //      c. Cache: update evaluationMemCacheDao
    //    Without lock at Storage layer, getBy() could read stale cache while SQL is already updated,
    //    resulting in inconsistent state between storage layers!
    //
    // Why NOT Lock in InMemoryCache?
    // - Even if InMemoryCache has its own lock for dictionary access, we STILL need lock here
    //   to ensure atomicity of compound operations across SQL + UserDefaults + Cache
    // - Would result in 2 locks (InMemoryCache + Storage) with no benefit, just added complexity
    // - Lock in InMemoryCache only protects dictionary access, NOT the compound operation atomicity
    // - Current design: Single lock at Storage layer protects BOTH thread-safety AND atomicity
    //
    // Example Race Condition Without Storage-Level Lock:
    //   Thread 1 (SDK Queue): update() reads SQL -> modifies data -> writes SQL + Cache
    //   Thread 2 (Main):      getBy() reads Cache (gets inconsistent data between read and write)
    //   Result: User sees evaluation that doesn't match what's in SQL!
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

    // forceUpdate performs an atomic compound operation:
    // 1. SQL: Delete all existing evaluations and insert new ones (in transaction)
    // 2. UserDefaults: Update evaluatedAt and currentEvaluationsId
    // 3. Cache: Update evaluationMemCacheDao
    // The caller (deleteAllAndInsert/update) must hold the lock to ensure atomicity across all three storage layers
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
        // Update in-memory cache to reflect the new state
        evaluationMemCacheDao.set(key: userId, value: evaluations)
    }

    // update performs incremental update of evaluations:
    // 1. Fetch current evaluations from SQL
    // 2. Upsert new evaluations (update existing or add new)
    // 3. Remove archived feature flags
    // 4. Atomically update all storage layers (SQL + UserDefaults + Cache)
    // Returns true if any changes were made (new evaluations or archived features)
    func update(
        evaluationId: String ,
        evaluations: [Evaluation],
        archivedFeatureIds: [String],
        evaluatedAt: String) throws -> Bool {
        try lock.withLock {
            // 1. Build a map of current evaluations by featureId
            var currentEvaluationsByFeatureId = try evaluationSQLDao.get(userId: userId)
                .reduce([String:Evaluation]()) { (input, evaluation) -> [String:Evaluation] in
                    var output = input
                    output[evaluation.featureId] = evaluation
                    return output
                }
            // 2. Upsert new evaluations (overwrite existing or add new)
            for evaluation in evaluations {
                currentEvaluationsByFeatureId[evaluation.featureId] = evaluation
            }
            // 3. Filter out archived features to get active evaluations
            let currentEvaluations = currentEvaluationsByFeatureId.values.filter { evaluation in
                !archivedFeatureIds.contains(evaluation.featureId)
            }.map { item in
                item
            }
            // 4. Atomically save to all storage layers
            try forceUpdate(
                evaluationId: evaluationId ,
                evaluations: currentEvaluations,
                evaluatedAt: evaluatedAt)
            return evaluations.count > 0 || archivedFeatureIds.count > 0
        }
    }

    // getBy returns data from the in-memory cache for fast access.
    // This is called on every feature flag evaluation (from main thread via BKTClient.getBKTEvaluationDetails),
    // so using the cache avoids expensive SQL queries on the critical path.
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
