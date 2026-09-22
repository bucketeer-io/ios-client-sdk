import Foundation

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

    var userAttributesState: UserAttributesState {
        // read atomically 2 values
        return setUserAttributesUpdatedLock.withLock {
            return UserAttributesState(
                version: userAttributesUpdatedVersion,
                isUpdated: evaluationUserDefaultsDao.userAttributesUpdated
            )
        }
    }

    private let userId: String
    private let evaluationSQLDao: EvaluationSQLDao
    private let evaluationMemCacheDao: EvaluationMemCacheDao
    private let evaluationUserDefaultsDao: EvaluationUserDefaultsDao
    /// Serializes the read-then-write in `deleteAllAndInsert` and `update`.
    ///
    /// The staleness guard reads the stored `evaluatedAt` and then writes. Without this
    /// lock, two writers could both read the same stored value, both pass the guard, and
    /// the older one could commit last: the exact rewind the guard exists to prevent.
    /// Callers are supposed to be on the SDK queue, but that is only a doc comment today,
    /// so this makes the guard hold even if that contract is ever violated. Deliberately a
    /// separate lock from `setUserAttributesUpdatedLock`, which guards unrelated state.
    private let writeLock = NSLock()
    private let setUserAttributesUpdatedLock = NSLock()
    /// Version counter used as an in-memory transaction id for attribute updates.
    /// Protected by `setUserAttributesUpdatedLock`.
    private var userAttributesUpdatedVersion: Int = 0

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

    /// `true` when `evaluatedAt` is strictly older than what is already stored.
    ///
    /// Guards the race where a slow poll response lands after fresher streamed data and
    /// rewinds the cache. Strictly older only: an equal `evaluatedAt` still applies,
    /// because two payloads computed in the same clock tick are not stale relative to
    /// each other, and dropping an equal-timestamp write would be a worse failure than
    /// the race this guards against.
    ///
    /// If either side is not a readable number, the write is allowed. That keeps today's
    /// polling behavior for a response carrying an empty `createdAt`, and fails toward
    /// writing rather than toward silent data loss. The streaming path rejects an
    /// unreadable timestamp one layer up, in
    /// `EvaluationInteractorImpl.applyStreamedEvaluations(_:shouldNotify:)`.
    private func isStale(incoming evaluatedAt: String) -> Bool {
        guard let incoming = Int64(evaluatedAt),
              let stored = Int64(evaluationUserDefaultsDao.evaluatedAt) else {
            return false
        }
        return incoming < stored
    }

    /// Unguarded write. Callers must already hold `writeLock` and must have checked
    /// `isStale(incoming:)`. Never call this from outside this type.
    private func performWrite(
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

    /// Deletes all evaluations and inserts new evaluations in storage.
    /// - Note: Caller must ensure this is called from the SDK queue.
    @discardableResult func deleteAllAndInsert(
        evaluationId: String,
        evaluations: [Evaluation],
        evaluatedAt: String) throws -> Bool {
        try writeLock.withLock {
            guard !isStale(incoming: evaluatedAt) else { return false }
            try performWrite(evaluationId: evaluationId, evaluations: evaluations, evaluatedAt: evaluatedAt)
            return true
        }
    }

    /// Updates evaluations in storage.
    /// - Note: Caller must ensure this is called from the SDK queue.
    func update(
        evaluationId: String ,
        evaluations: [Evaluation],
        archivedFeatureIds: [String],
        evaluatedAt: String) throws -> Bool {
        try writeLock.withLock {
            guard !isStale(incoming: evaluatedAt) else { return false }
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
            }
            // 4. Save to database
            try performWrite(
                evaluationId: evaluationId ,
                evaluations: Array(currentEvaluations),
                evaluatedAt: evaluatedAt)
            return evaluations.count > 0 || archivedFeatureIds.count > 0
        }
    }

    // getBy will return the data from the cache to speed up the response time
    func getBy(featureId: String) -> Evaluation? {
        // evaluationMemCacheDao is thread-safe (uses internal concurrent queue).
        // We rely on it without adding extra locks even though this storage layer can be accessed from multiple threads:
        // writes and most operations are serialized on the SDK queue, but reads (like getBy) may be invoked from the
        // main/UI thread concurrently with background SDK operations.
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
            userAttributesUpdatedVersion += 1
            evaluationUserDefaultsDao.setUserAttributesUpdated(value: true)
        }
    }

    // Called from SDK queue (fetch callback)
    @discardableResult func clearUserAttributesUpdated(state: UserAttributesState) -> Bool {
        guard state.isUpdated else {
            // No-op if flag is already false
            return false
        }
        return setUserAttributesUpdatedLock.withLock {
            // Only clear if the version matches what we captured at the start of the request.
            // If userAttributesUpdatedVersion > version, it means a new update happened
            // while the request was in-flight, so we MUST NOT clear the flag.
            if userAttributesUpdatedVersion == state.version {
                evaluationUserDefaultsDao.setUserAttributesUpdated(value: false)
                return true
            }
            return false
        }
    }
}
