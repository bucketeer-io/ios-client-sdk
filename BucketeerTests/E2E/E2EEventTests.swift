import Foundation
import XCTest
@testable import Bucketeer

@available(iOS 13, *)
final class E2EEventTests: XCTestCase {

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

    // Metrics Event Tests
    // refs: https://github.com/bucketeer-io/javascript-client-sdk/blob/main/e2e/events.spec.ts#L112
    func testEvaluationEvents() async throws {
        do {
            let client = try BKTClient.shared
            XCTAssertEqual(client.stringVariation(featureId: FEATURE_ID_STRING, defaultValue: ""), "value-1")
            XCTAssertEqual(client.intVariation(featureId: FEATURE_ID_INT, defaultValue: 0), 10)
            XCTAssertEqual(client.doubleVariation(featureId: FEATURE_ID_DOUBLE, defaultValue: 0.0), 2.1)
            XCTAssertEqual(client.boolVariation(featureId: FEATURE_ID_BOOLEAN, defaultValue: false), true)
            XCTAssertEqual(client.jsonVariation(featureId: FEATURE_ID_JSON, defaultValue: [:]), ["key":"value-1"])

            guard let component = client.component as? ComponentImpl else {
                XCTFail("could not access client.component")
                return
            }

            // getVariationValue() is logging events using another dispatch queue, we need to wait a few secs
            try await Task.sleep(nanoseconds: 10_000_000)
            let events = try component.dataModule.eventDao.getEvents()
            // It includes the Latency and ResponseSize metrics
            XCTAssertEqual(events.count, 7)
            XCTAssertTrue(events.contains { event in
                // event.type == EventType.evaluation && event.event.reason.type == "DEFAULT"
                if case .evaluation = event.type,
                   case .evaluation(let data) = event.event,
                   case .`default` = data.reason.type {
                    return true
                }
                return false
            })

            try await client.flush()

            XCTAssertEqual(try component.dataModule.eventDao.getEvents().count, 0)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testDefaultEvaluationEvents() async throws {
    }

    // altering featureTag should not affect api request
    func testAlteringFeatureTagShouldNotAffectAPIRequest() async throws {
    }

    // Altering the api key should not affect api request
    func testAlteringTheAPIKeyShouldNotAffectAPIRequest() async throws {
    }

    // Using a random string in the api key setting should throw Forbidden
    func testUsingRamdomStringInTheAPIKeyShouldThrowForbiden() async throws {
    }

    // Using a random string in the featureTag setting should not affect api request
    func testARandomStringInTheFeatureTagShouldNotAffectAPIRequest() async throws {
    }

    func testTimeout() async throws {
    }
}
