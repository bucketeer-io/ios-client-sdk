import Foundation
import XCTest
import Bucketeer

final class BucketeerE2ETests: XCTestCase {

    private var config: BKTConfig!

    @MainActor
    override func setUp() async throws {
        try await super.setUp()

        UserDefaults.standard.removeObject(forKey: "bucketeer_user_evaluations_id")

        let config = try BKTConfig.e2e()
        let user = try BKTUser(id: USER_ID)
        try await BKTClient.initialize(
            config: config,
            user: user
        )
    }

    @MainActor
    override func tearDown() async throws {
        try await super.tearDown()

        try await BKTClient.shared.flush()
        BKTClient.destroy()
        UserDefaults.standard.removeObject(forKey: "bucketeer_user_evaluations_id")
        try FileManager.default.removeItem(at: .database)
    }

    func testStringVariation() {
        let client = BKTClient.shared
        XCTAssertEqual(client.stringVariation(featureId: FEATURE_ID_STRING, defaultValue: ""), "value-1")
    }

    func testStringVariationDetail() {
        let client = BKTClient.shared
        let actual = client.evaluationDetails(featureId: FEATURE_ID_STRING)

        assertEvaluation(actual: actual, expected: .init(
            id: "feature-ios-e2e-string:2:bucketeer-ios-user-id-1",
            featureId: FEATURE_ID_STRING,
            featureVersion: 2,
            variationId: "349ed945-d2f9-4d04-8e83-82344cffd1ec",
            variationValue: "value-1",
            reason: .default
        ))
    }

    func testIntVariation() {
        let client = BKTClient.shared
        XCTAssertEqual(client.intVariation(featureId: FEATURE_ID_INT, defaultValue: 0), 10)
    }

    func testIntVariationDetail() {
        let client = BKTClient.shared
        let actual = client.evaluationDetails(featureId: FEATURE_ID_INT)

        assertEvaluation(actual: actual, expected: .init(
            id: "feature-ios-e2e-integer:2:bucketeer-ios-user-id-1",
            featureId: FEATURE_ID_INT,
            featureVersion: 2,
            variationId: "9c5fd2d2-d587-4ba2-8de2-0fc9454d564e",
            variationValue: "10",
            reason: .default
        ))
    }

    func testDoubleVariation() {
        let client = BKTClient.shared
        XCTAssertEqual(client.doubleVariation(featureId: FEATURE_ID_DOUBLE, defaultValue: 0.1), 2.1)
    }

    func testDoubleVariationDetail() async throws {
        let client = BKTClient.shared
        let actual = client.evaluationDetails(featureId: FEATURE_ID_DOUBLE)

        assertEvaluation(actual: actual, expected: .init(
            id: "feature-ios-e2e-double:2:bucketeer-ios-user-id-1",
            featureId: FEATURE_ID_DOUBLE,
            featureVersion: 2,
            variationId: "38078d8f-c6eb-4b93-9d58-c3e57010983f",
            variationValue: "2.1",
            reason: .default
        ))
    }

    func testBoolVariation() {
        let client = BKTClient.shared
        XCTAssertEqual(client.boolVariation(featureId: FEATURE_ID_BOOLEAN, defaultValue: false), true)
    }

    func testBoolVariationDetail() {
        let client = BKTClient.shared
        let actual = client.evaluationDetails(featureId: FEATURE_ID_BOOLEAN)

        assertEvaluation(actual: actual, expected: .init(
            id: "feature-ios-e2e-bool:2:bucketeer-ios-user-id-1",
            featureId: FEATURE_ID_BOOLEAN,
            featureVersion: 2,
            variationId: "4f9e0f88-e053-42a9-93e1-95d407f67021",
            variationValue: "true",
            reason: .default
        ))
    }

    func testJSONVariation() {
        let client = BKTClient.shared
        let json = client.jsonVariation(featureId: FEATURE_ID_JSON, defaultValue: [:])
        XCTAssertEqual(json as? [String: String], ["key": "value-1"])
    }

    func testJSONVariationDetail() {
        let client = BKTClient.shared
        let actual = client.evaluationDetails(featureId: FEATURE_ID_JSON)

        assertEvaluation(actual: actual, expected: .init(
            id: "feature-ios-e2e-json:2:bucketeer-ios-user-id-1",
            featureId: FEATURE_ID_JSON,
            featureVersion: 2,
            variationId: "06f5be6b-0c79-431f-a057-822babd9d3eb",
            variationValue: "{ \"key\": \"value-1\" }",
            reason: .default
        ))
    }

    func testEvaluationUpdateFlow() async throws {
        let client = BKTClient.shared
        XCTAssertEqual(client.stringVariation(featureId: FEATURE_ID_STRING, defaultValue: ""), "value-1")

        client.updateUserAttributes(attributes: ["app_version": "0.0.1"])

        try await client.fetchEvaluations(timeoutMillis: nil)
        XCTAssertEqual(client.stringVariation(featureId: FEATURE_ID_STRING, defaultValue: ""), "value-2")

        let details = client.evaluationDetails(featureId: FEATURE_ID_STRING)
        assertEvaluation(actual: details, expected: .init(
            id: "feature-ios-e2e-string:2:bucketeer-ios-user-id-1",
            featureId: FEATURE_ID_STRING,
            featureVersion: 2,
            variationId: "b4931643-e82f-4079-bd3c-aed02852cdd6",
            variationValue: "value-2",
            reason: .rule
        ))
    }

    func testTrack() async throws {
        let client = BKTClient.shared
        client.assert(expectedEventCount: 2)
        client.track(goalId: GOAL_ID, value: GOAL_VALUE)
        try await Task.sleep(nanoseconds: 1_000_000)
        client.assert(expectedEventCount: 3)
        try await client.flush()
        client.assert(expectedEventCount: 0)
    }
}
