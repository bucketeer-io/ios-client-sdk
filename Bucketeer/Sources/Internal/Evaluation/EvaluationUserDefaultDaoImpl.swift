import Foundation

class EvaluationUserDefaultDaoImpl: EvaluationUserDefaultsDao {

    private let defs: Defaults

    init(defaults: Defaults) {
        defs = defaults
    }

    var userAttributesUpdated: Bool {
        get {
            return defs.bool(forKey: EvaluationUserDefaultsKey.userAttributesUpdated.rawValue)
        }
        set {
            defs.set(newValue, forKey: EvaluationUserDefaultsKey.userAttributesUpdated.rawValue)
        }
    }
    var currentEvaluationsId: String {
        get {
            return defs.string(forKey: EvaluationUserDefaultsKey.userEvaluationsId.rawValue) ?? ""
        }
        set {
            defs.set(newValue, forKey: EvaluationUserDefaultsKey.userEvaluationsId.rawValue)
        }
    }
    var featureTag: String {
        get {
            return defs.string(forKey: EvaluationUserDefaultsKey.featureTag.rawValue) ?? ""
        }
        set {
            defs.set(newValue, forKey: EvaluationUserDefaultsKey.featureTag.rawValue)
        }
    }
    var evaluatedAt: String {
        get {
            return defs.string(forKey: EvaluationUserDefaultsKey.evaluatedAt.rawValue) ?? "0"
        }
        set {
            defs.set(newValue, forKey: EvaluationUserDefaultsKey.evaluatedAt.rawValue)
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
}
