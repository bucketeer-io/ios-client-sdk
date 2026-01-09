import Foundation

class EvaluationUserDefaultDaoImpl: EvaluationUserDefaultsDao {
    private static let userEvaluationsIdKey = "bucketeer_user_evaluations_id"
    private static let featureTagKey = "bucketeer_feature_tag"
    private static let evaluatedAtKey = "bucketeer_evaluated_at"
    private static let userAttributesUpdatedKey = "bucketeer_user_attributes_updated"
    private let defs: Defaults

    init(defaults: Defaults) {
        defs = defaults
    }

    var userAttributesUpdated: Bool {
        get {
            return defs.bool(forKey: Self.userAttributesUpdatedKey)
        }
        set {
            defs.set(newValue, forKey: Self.userAttributesUpdatedKey)
        }
    }
    var currentEvaluationsId: String {
        get {
            return defs.string(forKey: Self.userEvaluationsIdKey) ?? ""
        }
        set {
            defs.set(newValue, forKey: Self.userEvaluationsIdKey)
        }
    }
    var featureTag: String {
        get {
            return defs.string(forKey: Self.featureTagKey) ?? ""
        }
        set {
            defs.set(newValue, forKey: Self.featureTagKey)
        }
    }
    var evaluatedAt: String {
        get {
            return defs.string(forKey: Self.evaluatedAtKey) ?? "0"
        }
        set {
            defs.set(newValue, forKey: Self.evaluatedAtKey)
        }
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

    // Delete all related data for testing purposes
    func deleteAll() {
        defs.removeObject(forKey: Self.userEvaluationsIdKey)
        defs.removeObject(forKey: Self.featureTagKey)
        defs.removeObject(forKey: Self.evaluatedAtKey)
        defs.removeObject(forKey: Self.userAttributesUpdatedKey)
    }
}
