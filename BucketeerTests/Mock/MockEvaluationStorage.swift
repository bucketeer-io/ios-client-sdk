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
    typealias GetHandler = (String) throws -> [Evaluation]
    typealias DeleteAllAndInsertHandler = (String, [Evaluation]) throws -> Void
    typealias UpdateHandler = ([Evaluation], [String], String) throws -> Bool
    typealias GetByFeatureIdHandler = (String, String) -> Evaluation?
    typealias RefreshCacheHandler = () -> Void

    let getHandler: GetHandler?
    let updateHandler: UpdateHandler?
    let deleteAllAndInsertHandler: DeleteAllAndInsertHandler?
    let getByFeatureIdHandler: GetByFeatureIdHandler?
    let evaluationUserDefaultsDao = MockEvaluationUserDefaultsDao()
    let refreshCacheHandler: RefreshCacheHandler?

    init(getHandler: GetHandler? = nil,
         updateHandler: UpdateHandler? = nil,
         deleteAllAndInsertHandler: DeleteAllAndInsertHandler? = nil,
         getByFeatureIdHandler: GetByFeatureIdHandler? = nil,
         refreshCacheHandler: RefreshCacheHandler? = nil) {
        self.getHandler = getHandler
        self.deleteAllAndInsertHandler = deleteAllAndInsertHandler
        self.updateHandler = updateHandler
        self.getByFeatureIdHandler = getByFeatureIdHandler
        self.refreshCacheHandler = refreshCacheHandler
    }

    func get(userId: String) throws -> [Evaluation] {
        return try getHandler?(userId) ?? []
    }

    func deleteAllAndInsert(userId: String, evaluations: [Bucketeer.Evaluation], evaluatedAt: String) throws {
        try deleteAllAndInsertHandler?(userId, evaluations)
        // Mock save evaluatedAt
        evaluationUserDefaultsDao.evaluatedAt = evaluatedAt
    }

    func update(evaluations: [Evaluation], archivedFeatureIds: [String], evaluatedAt: String) throws -> Bool {
        let result = try updateHandler?(evaluations, archivedFeatureIds, evaluatedAt) ?? false
        // Mock save evaluatedAt
        evaluationUserDefaultsDao.evaluatedAt = evaluatedAt
        return result
    }

    func getBy(userId: String, featureId: String) -> Evaluation? {
        return getByFeatureIdHandler?(userId, featureId)
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

    func setUserAttributesUpdated(value: Bool) {
        userAttributesUpdated = value
    }
}
