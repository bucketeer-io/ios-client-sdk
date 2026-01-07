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

    var userAttributesUpdated: Bool {
        get {
            return evaluationUserDefaultsDao.userAttributesUpdated
        }
        set {
            evaluationUserDefaultsDao.userAttributesUpdated = newValue
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
    let getByFeatureIdHandler: GetByFeatureIdHandler?
    let evaluationUserDefaultsDao = MockEvaluationUserDefaultsDao()
    let refreshCacheHandler: RefreshCacheHandler?
    let userId: String
    var setUserAttributesUpdatedLock = NSLock()

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
        evaluations: [Bucketeer.Evaluation], evaluatedAt: String) throws {
        try deleteAllAndInsertHandler?(evaluations)
        // Mock save evaluatedAt
        evaluationUserDefaultsDao.evaluatedAt = evaluatedAt
        evaluationUserDefaultsDao.currentEvaluationsId = evaluationId
    }

    func update(
        evaluationId: String,
        evaluations: [Evaluation], archivedFeatureIds: [String], evaluatedAt: String) throws -> Bool {
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
            _userAttributesUpdatedVersion += 1
            userAttributesUpdated = true
        }
    }

    func clearCurrentEvaluationsId() {
        currentEvaluationsId = ""
    }

    var userAttributesUpdatedVersion: Int {
        return setUserAttributesUpdatedLock.withLock {
            return _userAttributesUpdatedVersion
        }
    }
    
    private var _userAttributesUpdatedVersion: Int = 0

    func clearUserAttributesUpdated(version: Int) {
        setUserAttributesUpdatedLock.withLock {
            if _userAttributesUpdatedVersion == version {
                userAttributesUpdated = false
            }
        }
    }
}
