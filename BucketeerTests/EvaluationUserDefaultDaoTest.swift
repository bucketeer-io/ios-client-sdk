import XCTest
@testable import Bucketeer

final class EvaluationUserDefaultDaoTests: XCTestCase {

    func testGetSet() {
        let defaults = MockDefaults()
        let userEvalutionStorage = EvaluationUserDefaultDaoImpl(defaults: defaults)
        XCTAssertEqual(userEvalutionStorage.currentEvaluationsId, "")
        XCTAssertEqual(userEvalutionStorage.featureTag, "")
        XCTAssertEqual(userEvalutionStorage.evaluatedAt, "0", "evaluatedAt should be `0` if it didn't save before")
        XCTAssertEqual(userEvalutionStorage.userAttributesUpdated, false)
        // Prefill state
        userEvalutionStorage.currentEvaluationsId = "1"
        userEvalutionStorage.featureTag = "tag"
        userEvalutionStorage.evaluatedAt = "22334455"
        userEvalutionStorage.userAttributesUpdated = true
        XCTAssertEqual(userEvalutionStorage.currentEvaluationsId, "1")
        XCTAssertEqual(userEvalutionStorage.featureTag, "tag")
        XCTAssertEqual(userEvalutionStorage.evaluatedAt, "22334455")
        XCTAssertEqual(userEvalutionStorage.userAttributesUpdated, true)
    }
}
