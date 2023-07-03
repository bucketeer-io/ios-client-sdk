import Foundation
import XCTest
@testable import Bucketeer

let FEATURE_TAG = "ios"
let USER_ID = "bucketeer-ios-user-id-1"

let FEATURE_ID_BOOLEAN = "feature-ios-e2e-bool"
let FEATURE_ID_STRING = "feature-ios-e2e-string"
let FEATURE_ID_INT = "feature-ios-e2e-integer"
let FEATURE_ID_DOUBLE = "feature-ios-e2e-double"
let FEATURE_ID_JSON = "feature-ios-e2e-json"

let GOAL_ID = "goal-ios-e2e-1"
let GOAL_VALUE = 1.0

@available(iOS 13, *)
extension BKTConfig {
    static func e2e() throws -> BKTConfig {
        let apiKey = ProcessInfo.processInfo.environment["E2E_API_KEY"]!
        let apiEndpoint = ProcessInfo.processInfo.environment["E2E_API_ENDPOINT"]!
        let builder = BKTConfig.Builder()
            .with(apiKey: apiKey)
            .with(apiEndpoint: apiEndpoint)
            .with(featureTag: FEATURE_TAG)
            .with(appVersion: "1.2.3")
            .with(logger: E2ELogger())

        return try builder.build()
    }
}

@available(iOS 13, *)
extension BKTClient {
    static func initialize(config: BKTConfig, user: BKTUser, timeoutMillis: Int64 = 5000) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                self.initialize(config: config, user: user) { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
        }
    }
    func fetchEvaluations(timeoutMillis: Int64?) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            self.fetchEvaluations(timeoutMillis: timeoutMillis) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func flush() async throws {
        return try await withCheckedThrowingContinuation({ continuation in
            self.flush { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        })
    }

    func assert(expectedEventCount: Int, file: StaticString = #filePath, line: UInt = #line) {
        let component = self.component as? ComponentImpl
        let count = try? component?.dataModule.eventDao.getEvents().count
        XCTAssertEqual(expectedEventCount, count, file: file, line: line)
    }
}

struct BKTEvaluationExpected {
    var id: String?
    var featureId: String?
    var featureVersion: Int?
    var userId: String?
    var variationId: String?
    var variationValue: String?
    var reason: BKTEvaluation.Reason?
}

func assertEvaluation(actual: BKTEvaluation?, expected: BKTEvaluationExpected, file: StaticString = #filePath, line: UInt = #line) {
    var isChecked: Bool = false
    if let value = expected.id {
        XCTAssertEqual(actual?.id, value, file: file, line: line)
        isChecked = true
    }
    if let value = expected.featureId {
        XCTAssertEqual(actual?.featureId, value, file: file, line: line)
        isChecked = true
    }
    if let value = expected.featureVersion {
        XCTAssertEqual(actual?.featureVersion, value, file: file, line: line)
        isChecked = true
    }
    if let value = expected.userId {
        XCTAssertEqual(actual?.userId, value, file: file, line: line)
        isChecked = true
    }
    if let value = expected.variationId {
        XCTAssertEqual(actual?.variationId, value, file: file, line: line)
        isChecked = true
    }
    if let value = expected.variationValue {
        XCTAssertEqual(actual?.variationValue, value, file: file, line: line)
        isChecked = true
    }
    if let value = expected.reason {
        XCTAssertEqual(actual?.reason, value, file: file, line: line)
        isChecked = true
    }
    if !isChecked {
        XCTFail("Expected BKTEvaluation is empty")
    }
}

final class E2ELogger: BKTLogger {
    private var prefix: String {
        "Bucketeer E2E "
    }

    func debug(message: String) {
        print("\(prefix)[DEBUG] \(message)")
    }

    func warn(message: String) {
        print("\(prefix)[WARN] \(message)")
    }

    func error(_ error: Error) {
        print("\(prefix)[ERROR] \(error)")
    }
}

extension URL {
    static var database: URL {
        // swiftlint:disable force_try
        let directoryURL = try! FileManager.default
            .url(for: DatabaseOpenHelper.directory, in: .userDomainMask, appropriateFor: nil, create: true)
        return directoryURL.appendingPathComponent(Constant.DB.FILE_NAME)
        // swiftlint:enable force_try
    }
}
