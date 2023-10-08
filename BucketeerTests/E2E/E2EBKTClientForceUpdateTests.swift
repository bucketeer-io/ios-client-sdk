import Foundation
import XCTest
@testable import Bucketeer

@available(iOS 13, *)
final class E2EBKTClientForceUpdateTests: XCTestCase {

    private var config: BKTConfig!

    override func setUp() async throws {
        try await super.setUp()

        UserDefaults.standard.removeObject(forKey: "bucketeer_user_evaluations_id")
        UserDefaults.standard.removeObject(forKey: "bucketeer_feature_tag")
        UserDefaults.standard.removeObject(forKey: "bucketeer_evaluatedAt")
        UserDefaults.standard.removeObject(forKey: "bucketeer_userAttributesUpdated")
        UserDefaults.standard.removeObject(forKey: "bucketeer_user_evaluations_id")
    }

    @MainActor
    override func tearDown() async throws {
        try await super.tearDown()

        try await BKTClient.shared.flush()
        try BKTClient.destroy()
        UserDefaults.standard.removeObject(forKey: "bucketeer_user_evaluations_id")
        try FileManager.default.removeItem(at: .database)
    }

    // "userEvaluationsId is different and evaluatedAt is too old"
    func testUserEvaluationsIdMismatchAndEvaluatedAtTooOld () async throws {
        let config = try BKTConfig.e2e()
        let user = try BKTUser.Builder().with(id: USER_ID).build()

        let internalDataModule = try DataModuleImpl(user: user.toUser(), config: config)
        var internalEvaluationStorage = internalDataModule.evaluationStorage
        let userId = USER_ID
        let tobeDeletedEvaluation = Evaluation(
            id: "evaluation1",
            featureId: "feature1",
            featureVersion: 1,
            userId: USER_ID,
            variationId: "variation1",
            variationName: "variation name1",
            variationValue: "variation_value1",
            reason: .init(
                type: .rule,
                ruleId: "rule1"
            )
        )
        let randomUserEvaluationId = "3227641913513702639"
        let tooOldEvaluatedAt = "1"
        // Prefill data
        try internalEvaluationStorage.deleteAllAndInsert(
            evaluationId: randomUserEvaluationId,
            evaluations: [tobeDeletedEvaluation],
            evaluatedAt: tooOldEvaluatedAt
        )

        XCTAssertEqual(internalEvaluationStorage.evaluatedAt, tooOldEvaluatedAt)
        XCTAssertEqual(internalEvaluationStorage.currentEvaluationsId, randomUserEvaluationId)

        let evaluations = try internalEvaluationStorage.get()
        XCTAssertEqual(evaluations, [tobeDeletedEvaluation], "We should have `tobeDeletedEvaluation` on the cache")

        // note: we need prepare the context before initialize the BKTClient
        // because on initialize() the BKTClient will auto fetch the evalutation
        try await BKTClient.initialize(
            config: config,
            user: user
        )
        let client = try BKTClient.shared
        guard let component = client.component as? ComponentImpl else {
            XCTFail("could not access client.component")
            return
        }

        let evaluationStorage = component.dataModule.evaluationStorage
        XCTAssertNotEqual(evaluationStorage.evaluatedAt, tooOldEvaluatedAt)
        XCTAssertNotEqual(evaluationStorage.currentEvaluationsId, randomUserEvaluationId)

        let currentEvaluations = try evaluationStorage.get()
        XCTAssertEqual(currentEvaluations.isEmpty, false)
        XCTAssertFalse(currentEvaluations.contains(tobeDeletedEvaluation), "we should not have `tobeDeletedEvaluation` in the cache")
    }

    // userEvaluationId is empty after feature_tag changed
    func testInitializeWithNewFeatureTag() async throws {
        let config = try BKTConfig.e2e(featureTag: "android")
        let userId = USER_ID
        let user = try BKTUser.Builder().with(id: userId).build()
        try await BKTClient.initialize(
            config: config,
            user: user
        )
        let client = try BKTClient.shared

        guard let component = client.component as? ComponentImpl else {
            XCTFail("could not access client.component")
            return
        }

        let evaluationStorage = component.dataModule.evaluationStorage
        XCTAssertNotEqual(evaluationStorage.evaluatedAt, "0")
        XCTAssertNotEqual(evaluationStorage.currentEvaluationsId, "")

        let currentEvaluations = try evaluationStorage.get()
        XCTAssertEqual(currentEvaluations.isEmpty, false)

        let tobeDeletedEvaluation = Evaluation(
            id: "evaluation1",
            featureId: "feature1",
            featureVersion: 1,
            userId: USER_ID,
            variationId: "variation1",
            variationName: "variation name1",
            variationValue: "variation_value1",
            reason: .init(
                type: .rule,
                ruleId: "rule1"
            )
        )

        let randomUserEvaluationId = "322764191351370263"
        try evaluationStorage.update(
            evaluationId: randomUserEvaluationId,
            evaluations: [tobeDeletedEvaluation], archivedFeatureIds: [], evaluatedAt: "1")
        let currentEvaluationsWithFakeData = try evaluationStorage.get()
        XCTAssertEqual(currentEvaluationsWithFakeData.count, currentEvaluations.count + 1)
        XCTAssertEqual(currentEvaluationsWithFakeData.contains(tobeDeletedEvaluation), true)
        XCTAssertEqual(evaluationStorage.currentEvaluationsId, randomUserEvaluationId)

        // Similate feature_tag changed
        try DispatchQueue.main.sync {
            try BKTClient.destroy()
        }

        let configWithFeatureTag = try BKTConfig.e2e(featureTag: FEATURE_TAG)
        try await BKTClient.initialize(
            config: configWithFeatureTag,
            user: user
        )
        let clientWithFeatureTag = try BKTClient.shared

        guard let componentWithFeatureTag = clientWithFeatureTag.component as? ComponentImpl else {
            XCTFail("could not access clientWithFeatureTag.component")
            return
        }

        let evaluationStorageWithFeatureTag = componentWithFeatureTag.dataModule.evaluationStorage
        XCTAssertNotEqual(evaluationStorageWithFeatureTag.currentEvaluationsId, "")
        XCTAssertNotEqual(client.component.evaluationInteractor.currentEvaluationsId, "")

        let currentEvaluationsWithOutFakeData = try evaluationStorageWithFeatureTag.get()
        // verify if `force_update` happened
        // if true , `tobeDeletedEvaluation` will no longer found in the cache
        XCTAssertEqual(currentEvaluationsWithOutFakeData.contains(tobeDeletedEvaluation), false)
    }

    func testInitWithoutFeatureTagShouldRetrievesAllFeatures() async throws {
        let config = try BKTConfig.e2e(featureTag: "")
        let userId = USER_ID
        let user = try BKTUser.Builder().with(id: userId).build()
        try await BKTClient.initialize(
            config: config,
            user: user
        )
        let client = try BKTClient.shared

        let android = client.evaluationDetails(featureId: "feature-android-e2e-string")
        XCTAssertNotNil(android)
        let golang = client.evaluationDetails(featureId: "feature-go-server-e2e-1")
        XCTAssertNotNil(golang)
        let javascript = client.evaluationDetails(featureId: "feature-js-e2e-string")
        XCTAssertNotNil(javascript)
    }
}
