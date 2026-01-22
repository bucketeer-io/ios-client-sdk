import Foundation
import XCTest
@testable import Bucketeer

@available(iOS 13, *)
final class E2EEventTests: XCTestCase {

    private var config: BKTConfig!

    override func setUp() async throws {
        try await super.setUp()
        UserDefaults.removeAllEvaluationData()

        let config = try BKTConfig.e2e()
        let user = try BKTUser.Builder().with(id: USER_ID).build()
        try await BKTClient.initialize(
            config: config,
            user: user
        )
    }

    override func tearDown() async throws {
        try await super.tearDown()

        try await BKTClient.shared.flush()
        try BKTClient.destroy()
        UserDefaults.removeAllEvaluationData()
        try FileManager.default.removeItem(at: .database)
    }

    func testTrack() async throws {
        do {
            let client = try BKTClient.shared
            client.assert(expectedEventCount: 2)
            client.track(goalId: GOAL_ID, value: GOAL_VALUE)

            guard let component = client.component as? ComponentImpl else {
                XCTFail("could not access client.component")
                return
            }

            try await Task.sleep(nanoseconds: 300_000_000)
            client.assert(expectedEventCount: 3)

            let events = try component.dataModule.eventSQLDao.getEvents()

            XCTAssertTrue(events.contains { event in
                if case .goal = event.type,
                   case .goal(let data) = event.event,
                   case .ios = data.sourceId,
                   data.sdkVersion == Version.current {
                    return true
                }
                return false
            })

            try await client.flush()
            client.assert(expectedEventCount: 0)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    // refs: https://github.com/bucketeer-io/javascript-client-sdk/blob/main/e2e/events.spec.ts#L112
    func testEvaluationEvents() async throws {
        do {
            let client = try BKTClient.shared
            XCTAssertEqual(client.stringVariation(featureId: FEATURE_ID_STRING, defaultValue: ""), "value-1")
            XCTAssertEqual(client.intVariation(featureId: FEATURE_ID_INT, defaultValue: 0), 10)
            XCTAssertEqual(client.intVariation(featureId: FEATURE_ID_DOUBLE, defaultValue: 0), 2)
            XCTAssertEqual(client.doubleVariation(featureId: FEATURE_ID_DOUBLE, defaultValue: 0.0), 2.1)
            XCTAssertEqual(client.boolVariation(featureId: FEATURE_ID_BOOLEAN, defaultValue: false), true)
            XCTAssertEqual(client.jsonVariation(featureId: FEATURE_ID_JSON, defaultValue: [:]), ["key":"value-1"])

            guard let component = client.component as? ComponentImpl else {
                XCTFail("could not access client.component")
                return
            }

            // getVariationValue() is logging events using another dispatch queue, we need to wait a few secs
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            let events = try component.dataModule.eventSQLDao.getEvents()
            // It includes the Latency and ResponseSize metrics
            XCTAssertTrue(events.count >= 5)
            XCTAssertTrue(events.contains { event in
                if case .evaluation = event.type,
                   case .evaluation(let data) = event.event,
                   case .default = data.reason.type,
                   case .ios = data.sourceId,
                   data.sdkVersion == Version.current {
                    return true
                }
                return false
            })

            try await client.flush()

            XCTAssertEqual(try component.dataModule.eventSQLDao.getEvents().count, 0)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testDefaultEvaluationEvents() async throws {
        do {
            let client = try BKTClient.shared
            guard let component = client.component as? ComponentImpl else {
                XCTFail("could not access client.component")
                return
            }
            try await withCheckedThrowingContinuation({ continuation in
                client.execute {
                    do {
                        try component.dataModule.evaluationStorage.deleteAllAndInsert(evaluationId: "evaluationId", evaluations: [], evaluatedAt: "0")
                        continuation.resume(returning: ())
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            })

            // Wait for the event to be added
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            // After clearing evaluations, we expect 2 metrics events (Latency and ResponseSize)
            client.assert(expectedEventCount: 2)

            // Wait for the clear operation to complete
            try await Task.sleep(nanoseconds: 300_000_000) // 300 milliseconds

            // Make variation calls to generate default evaluation events
            XCTAssertEqual(client.stringVariation(featureId: FEATURE_ID_STRING, defaultValue: "value-default"), "value-default")
            XCTAssertEqual(client.intVariation(featureId: FEATURE_ID_INT, defaultValue: 100), 100)
            XCTAssertEqual(client.doubleVariation(featureId: FEATURE_ID_DOUBLE, defaultValue: 3.0), 3.0)
            XCTAssertEqual(client.boolVariation(featureId: FEATURE_ID_BOOLEAN, defaultValue: false), false)
            XCTAssertEqual(client.jsonVariation(featureId: FEATURE_ID_JSON, defaultValue: ["key":"value-default"]), ["key":"value-default"])

            guard let component = client.component as? ComponentImpl else {
                XCTFail("could not access client.component")
                return
            }

            // Wait for events to be processed
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            let events = try component.dataModule.eventSQLDao.getEvents()
            // It includes the Latency and ResponseSize metrics
            XCTAssertTrue(events.count >= 7, "Expected at least 7 events but got \(events.count)")
            XCTAssertTrue(events.contains { event in
                if case .evaluation = event.type,
                   case .evaluation(let data) = event.event,
                   case .errorFlagNotFound = data.reason.type,
                   case .ios = data.sourceId,
                   data.sdkVersion == Version.current {
                    return true
                }
                return false
            })

            try await client.flush()

            XCTAssertEqual(try component.dataModule.eventSQLDao.getEvents().count, 0)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
}
