import Foundation
@testable import Bucketeer

final class MockEvaluationUserDefaultsDao: EvaluationUserDefaultsDao {
    var featureTag = ""
    var currentEvaluationsId = ""
    var evaluatedAt = "0"
    var userAttributesUpdated = false

    func setFeatureTag(value: String) {
        featureTag = value
    }

    func setCurrentEvaluationsId(value: String) {
        currentEvaluationsId = value
    }

    func setUserAttributesUpdated(value: Bool) {
        userAttributesUpdated = value
    }

    func setEvaluatedAt(value: String) {
        evaluatedAt = value
    }
}
