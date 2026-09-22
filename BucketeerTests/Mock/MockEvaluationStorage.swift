import Foundation
@testable import Bucketeer

final class MockEvaluationStorage: EvaluationStorage {

    var currentEvaluationsId: String {
        get {
            return evaluationUserDefaultsDao.currentEvaluationsId
        }
        set {
            evaluationUserDefaultsDao.currentEvaluationsId = newValue
        }
    }

    var featureTag: String {
        get {
            return evaluationUserDefaultsDao.featureTag
        }
        set {
            evaluationUserDefaultsDao.featureTag = newValue
        }
    }

    var evaluatedAt: String {
        get {
            return evaluationUserDefaultsDao.evaluatedAt
        }
        set {
            evaluationUserDefaultsDao.evaluatedAt = newValue
        }
    }

    typealias PutHandler = ((String, [Evaluation]) throws -> Void)
    typealias GetHandler = () throws -> [Evaluation]
    typealias DeleteAllAndInsertHandler = ([Evaluation]) throws -> Void
    typealias UpdateHandler = ([Evaluation], [String], String) throws -> Bool
    typealias GetByFeatureIdHandler = (String) -> Evaluation?
    typealias RefreshCacheHandler = () -> Void

    let getHandler: GetHandler?
    let updateHandler: UpdateHandler?
    let deleteAllAndInsertHandler: DeleteAllAndInsertHandler?
    /// When set and it returns true, the mock treats the write as stale and skips it,
    /// like `EvaluationStorageImpl`'s staleness guard, without duplicating that guard's
    /// rule here. Lets interactor tests drive the rejected-write branch.
    var isStaleWriteHandler: ((_ evaluatedAt: String) -> Bool)?
    let getByFeatureIdHandler: GetByFeatureIdHandler?
    let evaluationUserDefaultsDao = MockEvaluationUserDefaultsDao()
    let refreshCacheHandler: RefreshCacheHandler?
    let userId: String
    var setUserAttributesUpdatedLock = NSLock()
    // protected by setUserAttributesUpdatedLock
    private var userAttributesUpdatedVersion: Int = 0
    private var userAttributesUpdated: Bool {
        get {
            return evaluationUserDefaultsDao.userAttributesUpdated
        }
        set {
            evaluationUserDefaultsDao.userAttributesUpdated = newValue
        }
    }

    init(userId: String,
         getHandler: GetHandler? = nil,
         updateHandler: UpdateHandler? = nil,
         deleteAllAndInsertHandler: DeleteAllAndInsertHandler? = nil,
         getByFeatureIdHandler: GetByFeatureIdHandler? = nil,
         refreshCacheHandler: RefreshCacheHandler? = nil) {
        self.getHandler = getHandler
        self.deleteAllAndInsertHandler = deleteAllAndInsertHandler
        self.updateHandler = updateHandler
        self.getByFeatureIdHandler = getByFeatureIdHandler
        self.refreshCacheHandler = refreshCacheHandler
        self.userId = userId
    }

    func get() throws -> [Evaluation] {
        return try getHandler?() ?? []
    }

    func deleteAllAndInsert(
        evaluationId: String,
        evaluations: [Bucketeer.Evaluation], evaluatedAt: String) throws -> Bool {
        if isStaleWriteHandler?(evaluatedAt) == true { return false }
        try deleteAllAndInsertHandler?(evaluations)
        // Mock save evaluatedAt
        evaluationUserDefaultsDao.evaluatedAt = evaluatedAt
        evaluationUserDefaultsDao.currentEvaluationsId = evaluationId
        return true
    }

    func update(
        evaluationId: String,
        evaluations: [Evaluation], archivedFeatureIds: [String], evaluatedAt: String) throws -> Bool {
        if isStaleWriteHandler?(evaluatedAt) == true { return false }
        let result = try updateHandler?(evaluations, archivedFeatureIds, evaluatedAt) ?? false
        // Mock save evaluatedAt
        evaluationUserDefaultsDao.evaluatedAt = evaluatedAt
        evaluationUserDefaultsDao.currentEvaluationsId = evaluationId
        return result
    }

    func getBy(featureId: String) -> Evaluation? {
        return getByFeatureIdHandler?(featureId)
    }

    func refreshCache() throws {
        refreshCacheHandler?()
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

    func setUserAttributesUpdated() {
        setUserAttributesUpdatedLock.withLock {
            userAttributesUpdatedVersion += 1
            userAttributesUpdated = true
        }
    }

    func clearCurrentEvaluationsId() {
        currentEvaluationsId = ""
    }

    var userAttributesState: UserAttributesState {
        return setUserAttributesUpdatedLock.withLock {
            return UserAttributesState(
                version: userAttributesUpdatedVersion,
                isUpdated: userAttributesUpdated
            )
        }
    }

    func clearUserAttributesUpdated(state: UserAttributesState) -> Bool {
        guard state.isUpdated else { return false }
        return setUserAttributesUpdatedLock.withLock {
            if userAttributesUpdatedVersion == state.version {
                userAttributesUpdated = false
                return true
            }
            return false
        }
    }
}
