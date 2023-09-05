import Foundation

protocol EvaluationStorage {
    func getBy(userId: String, featureId: String) -> Evaluation?
    func get(userId: String) throws -> [Evaluation]
    // force update
    func deleteAllAndInsert(userId: String, evaluations: [Evaluation], evaluatedAt: String) throws
    // upsert
    @discardableResult func update(evaluations: [Evaluation], archivedFeatureIds: [String], evaluatedAt: String) throws -> Bool
    func refreshCache() throws

    var currentEvaluationsId: String { get }
    var featureTag: String { get }
    // expected set evaluatedAt from `deleteAllAndInsert` or `update` only
    var evaluatedAt: String { get }
    var userAttributesUpdated: Bool { get }

    func setCurrentEvaluationsId(value: String)
    func setFeatureTag(value: String)
    func setEvaluatedAt(value: String)
    func setUserAttributesUpdated(value: Bool)
}
