import Foundation
import XCTest
@testable import Bucketeer

@available(iOS 13, *)
final class E2EMetricsEventTests: XCTestCase {

    private var config: BKTConfig!

    override func tearDown() async throws {
        try await super.tearDown()
        try BKTClient.destroy()
        UserDefaults.removeAllEvaluationData()
        try? FileManager.default.removeItem(at: .database)
    }

    // Metrics Event Tests
    // refs: https://github.com/bucketeer-io/javascript-client-sdk/blob/main/e2e/events.spec.ts#L112

    // Using a random string in the api key setting should throw Forbidden
    func testUsingRamdomStringInTheAPIKeyShouldThrowForbiden() async throws {
        let apiKey = "some-random-string"
        let apiEndpoint = ProcessInfo.processInfo.environment["E2E_API_ENDPOINT"]!

        let builder = BKTConfig.Builder()
            .with(apiKey: apiKey)
            .with(apiEndpoint: apiEndpoint)
            .with(featureTag: FEATURE_TAG)
            .with(appVersion: "1.2.3")
            .with(logger: E2ELogger())

        let config = try builder.build()
        let user = try BKTUser.Builder().with(id: USER_ID).build()
        do {
            try await BKTClient.initialize(
                config: config,
                user: user
            )
            XCTFail("Using a random string in the api key setting should throw Forbidden")
        } catch {
            guard case BKTError.forbidden(_) = error else {
                XCTFail("Using a random string in the api key setting should throw Forbidden")
                return
            }
        }

        let client = try BKTClient.shared
        guard let component = client.component as? ComponentImpl else {
            XCTFail("could not access client.component")
            return
        }
        let events : [Event] = try component.dataModule.eventSQLDao.getEvents()
        // We did not generate error events for forbidden (403) errors. The event count is expected to be 0.
        XCTAssertFalse(events.contains { event in
            if case .metrics = event.type,
               case .metrics(let data) = event.event,
               case .forbiddenError = data.type,
               case .forbiddenError(let errorData) = data.event,
               case .getEvaluations = errorData.apiId {
                return true
            }
            return false
        })
        XCTAssertEqual(events.count, 0)

        do {
            try await client.flush()
        } catch {
            XCTFail("No events to flush; no request is sent, so no error is expected.")
        }

        let events2 : [Event] = try component.dataModule.eventSQLDao.getEvents()
        XCTAssertEqual(events2.count, 0)
    }

    // Using a random string in the featureTag setting should not affect api request
    func testARandomStringInTheFeatureTagShouldNotAffectAPIRequest() async throws {
        let featureTag = "some-random-string"
        let config = try BKTConfig.e2e(featureTag: featureTag)
        let user = try BKTUser.Builder().with(id: USER_ID).build()
        do {
            try await BKTClient.initialize(
                config: config,
                user: user
            )
        } catch {
            XCTFail("Using a random string in the featureTag setting should not affect api request")
        }
    }

    func testTimeout() async throws {
        let config = try BKTConfig.e2e()
        let user = try BKTUser.Builder().with(id: USER_ID).build()
        do {
            try await BKTClient.initialize(
                config: config,
                user: user,
                timeoutMillis: 10
            )
            XCTFail("Should throw timeout error")
        } catch {
            guard case BKTError.timeout( _, _, let timeoutMillis ) = error, timeoutMillis == 10 else {
                XCTFail("Should throw timeout error")
                return
            }
        }
        let client = try BKTClient.shared
        guard let component = client.component as? ComponentImpl else {
            XCTFail("could not access client.component")
            return
        }
        let events : [Event] = try component.dataModule.eventSQLDao.getEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertTrue(events.contains { event in
            if case .metrics = event.type,
               case .metrics(let data) = event.event,
               case .timeoutError = data.type,
               case .timeoutError(let errorData) = data.event,
               case .getEvaluations = errorData.apiId {
                return true
            }
            return false
        })

        try await client.flush()

        XCTAssertEqual(try component.dataModule.eventSQLDao.getEvents().count, 0)
    }
}
