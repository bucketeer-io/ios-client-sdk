import Foundation
import XCTest
import Bucketeer

@available(iOS 13, *)
final class BucketeerE2ETests: XCTestCase {

    private var config: BKTConfig!

    override func setUp() async throws {
        try await super.setUp()

        UserDefaults.standard.removeObject(forKey: "bucketeer_user_evaluations_id")

        let config = try BKTConfig.e2e()
        let user = try BKTUser.Builder().with(id: USER_ID).build()
        try await BKTClient.initialize(
            config: config,
            user: user
        )
    }

    @MainActor
    override func tearDown() async throws {
        try await super.tearDown()

        try await BKTClient.shared.flush()
        try BKTClient.destroy()
        UserDefaults.standard.removeObject(forKey: "bucketeer_user_evaluations_id")
        try FileManager.default.removeItem(at: .database)
    }

    func testStringVariation() {
        do {
            let client = try BKTClient.shared
            XCTAssertEqual(client.stringVariation(featureId: FEATURE_ID_STRING, defaultValue: ""), "value-1")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testStringVariationDetail() {
        do {
            let client = try BKTClient.shared
            let actual = client.evaluationDetails(featureId: FEATURE_ID_STRING)

            assertEvaluation(actual: actual, expected: .init(
                id: "feature-ios-e2e-string:3:bucketeer-ios-user-id-1",
                featureId: FEATURE_ID_STRING,
                featureVersion: 3,
                variationId: "349ed945-d2f9-4d04-8e83-82344cffd1ec",
                variationName: "variation 1",
                variationValue: "value-1",
                reason: .default
            ))
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testIntVariation() {
        do {
            let client = try BKTClient.shared
            XCTAssertEqual(client.intVariation(featureId: FEATURE_ID_INT, defaultValue: 0), 10)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testIntVariationDetail() {
        do {
            let client = try BKTClient.shared
            let actual = client.evaluationDetails(featureId: FEATURE_ID_INT)

            assertEvaluation(actual: actual, expected: .init(
                id: "feature-ios-e2e-integer:3:bucketeer-ios-user-id-1",
                featureId: FEATURE_ID_INT,
                featureVersion: 3,
                variationId: "9c5fd2d2-d587-4ba2-8de2-0fc9454d564e",
                variationName: "variation 10",
                variationValue: "10",
                reason: .default
            ))
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testDoubleVariation() {
        do {
            let client = try BKTClient.shared
            XCTAssertEqual(client.doubleVariation(featureId: FEATURE_ID_DOUBLE, defaultValue: 0.1), 2.1)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testDoubleVariationDetail() async throws {
        do {
            let client = try BKTClient.shared
            let actual = client.evaluationDetails(featureId: FEATURE_ID_DOUBLE)

            assertEvaluation(actual: actual, expected: .init(
                id: "feature-ios-e2e-double:3:bucketeer-ios-user-id-1",
                featureId: FEATURE_ID_DOUBLE,
                featureVersion: 3,
                variationId: "38078d8f-c6eb-4b93-9d58-c3e57010983f",
                variationName: "variation 2.1",
                variationValue: "2.1",
                reason: .default
            ))
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testBoolVariation() {
        do {
            let client = try BKTClient.shared
            let actual = client.evaluationDetails(featureId: FEATURE_ID_BOOLEAN)

            assertEvaluation(actual: actual, expected: .init(
                id: "feature-ios-e2e-bool:3:bucketeer-ios-user-id-1",
                featureId: FEATURE_ID_BOOLEAN,
                featureVersion: 3,
                variationId: "4f9e0f88-e053-42a9-93e1-95d407f67021",
                variationName: "variation true",
                variationValue: "true",
                reason: .default
            ))
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testBoolVariationDetail() {
        do {
            let client = try BKTClient.shared
            let actual = client.evaluationDetails(featureId: FEATURE_ID_BOOLEAN)

            assertEvaluation(actual: actual, expected: .init(
                id: "feature-ios-e2e-bool:3:bucketeer-ios-user-id-1",
                featureId: FEATURE_ID_BOOLEAN,
                featureVersion: 3,
                variationId: "4f9e0f88-e053-42a9-93e1-95d407f67021",
                variationName: "variation true",
                variationValue: "true",
                reason: .default
            ))
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testJSONVariation() {
        do {
            let client = try BKTClient.shared
            let json = client.jsonVariation(featureId: FEATURE_ID_JSON, defaultValue: [:])
            XCTAssertEqual(json as? [String: String], ["key": "value-1"])
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testJSONVariationDetail() {
        do {
            let client = try BKTClient.shared
            let actual = client.evaluationDetails(featureId: FEATURE_ID_JSON)

            assertEvaluation(actual: actual, expected: .init(
                id: "feature-ios-e2e-json:3:bucketeer-ios-user-id-1",
                featureId: FEATURE_ID_JSON,
                featureVersion: 3,
                variationId: "06f5be6b-0c79-431f-a057-822babd9d3eb",
                variationName: "variation 1",
                variationValue: "{ \"key\": \"value-1\" }",
                reason: .default
            ))
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testEvaluationUpdateFlow() async throws {
        do {
            let client = try BKTClient.shared
            XCTAssertEqual(client.stringVariation(featureId: FEATURE_ID_STRING, defaultValue: ""), "value-1")

            client.updateUserAttributes(attributes: ["app_version": "0.0.1"])

            try await client.fetchEvaluations(timeoutMillis: nil)
            XCTAssertEqual(client.stringVariation(featureId: FEATURE_ID_STRING, defaultValue: ""), "value-2")

            let details = client.evaluationDetails(featureId: FEATURE_ID_STRING)
            assertEvaluation(actual: details, expected: .init(
                id: "feature-ios-e2e-string:3:bucketeer-ios-user-id-1",
                featureId: FEATURE_ID_STRING,
                featureVersion: 3,
                variationId: "b4931643-e82f-4079-bd3c-aed02852cdd6",
                variationName: "variation 2",
                variationValue: "value-2",
                reason: .rule
            ))
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testTrack() async throws {
        do {
            let client = try BKTClient.shared
            client.assert(expectedEventCount: 2)
            client.track(goalId: GOAL_ID, value: GOAL_VALUE)
            try await Task.sleep(nanoseconds: 1_000_000)
            client.assert(expectedEventCount: 3)
            try await client.flush()
            client.assert(expectedEventCount: 0)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
}
