import Foundation

protocol EvaluationUserDefaultsDao {
    var currentEvaluationsId: String { get }
    var featureTag: String { get }
    var evaluatedAt: String { get }
    var userAttributesUpdated: Bool { get }

    func setCurrentEvaluationsId(value: String)
    func setFeatureTag(value: String)
    func setEvaluatedAt(value: String)
    func setUserAttributesUpdated(value: Bool)
}
