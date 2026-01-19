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

enum EvaluationUserDefaultsKey: String {
    case userEvaluationsId = "bucketeer_user_evaluations_id"
    case featureTag = "bucketeer_feature_tag"
    case evaluatedAt = "bucketeer_evaluated_at"
    case userAttributesUpdated = "bucketeer_user_attributes_updated"
}
