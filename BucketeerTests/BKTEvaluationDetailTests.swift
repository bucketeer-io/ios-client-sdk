import XCTest
@testable import Bucketeer

// swiftlint:disable function_body_length
final class BKTEvaluationDetailTests: XCTestCase {

    func testEqualable() throws {
        XCTAssertEqual(BKTEvaluationDetails(
            featureId: "1",
            featureVersion: 0,
            userId: "2",
            variationId: "",
            variationName: "",
            variationValue: 2,
            reason: .client), BKTEvaluationDetails(
                featureId: "1",
                featureVersion: 0,
                userId: "2",
                variationId: "",
                variationName: "",
                variationValue: 2,
                reason: .client))
        XCTAssertNotEqual(BKTEvaluationDetails(
            featureId: "1",
            featureVersion: 0,
            userId: "2",
            variationId: "",
            variationName: "",
            variationValue: 2,
            reason: .client), BKTEvaluationDetails(
                featureId: "12",
                featureVersion: 0,
                userId: "2",
                variationId: "",
                variationName: "",
                variationValue: 2,
                reason: .default))

        XCTAssertEqual(BKTEvaluationDetails(
            featureId: "2",
            featureVersion: 0,
            userId: "3",
            variationId: "",
            variationName: "",
            variationValue: "2",
            reason: .client), BKTEvaluationDetails(
                featureId: "2",
                featureVersion: 0,
                userId: "3",
                variationId: "",
                variationName: "",
                variationValue: "2",
                reason: .client))
        XCTAssertNotEqual(BKTEvaluationDetails(
            featureId: "2",
            featureVersion: 0,
            userId: "3",
            variationId: "",
            variationName: "",
            variationValue: "2",
            reason: .client), BKTEvaluationDetails(
                featureId: "2",
                featureVersion: 0,
                userId: "3",
                variationId: "",
                variationName: "",
                variationValue: "22",
                reason: .client))

        XCTAssertEqual(BKTEvaluationDetails(
            featureId: "3",
            featureVersion: 0,
            userId: "3",
            variationId: "",
            variationName: "",
            variationValue: 3.0,
            reason: .client), BKTEvaluationDetails(
                featureId: "3",
                featureVersion: 0,
                userId: "3",
                variationId: "",
                variationName: "",
                variationValue: 3.0,
                reason: .client))

        XCTAssertNotEqual(BKTEvaluationDetails(
            featureId: "3",
            featureVersion: 0,
            userId: "3",
            variationId: "",
            variationName: "",
            variationValue: 3.0,
            reason: .client), BKTEvaluationDetails(
                featureId: "3",
                featureVersion: 1,
                userId: "3",
                variationId: "",
                variationName: "",
                variationValue: 3.1,
                reason: .client))

        XCTAssertEqual(BKTEvaluationDetails(
            featureId: "4",
            featureVersion: 0,
            userId: "3",
            variationId: "",
            variationName: "",
            variationValue: true,
            reason: .client), BKTEvaluationDetails(
                featureId: "4",
                featureVersion: 0,
                userId: "3",
                variationId: "",
                variationName: "",
                variationValue: true,
                reason: .client))

        XCTAssertNotEqual(BKTEvaluationDetails(
            featureId: "4",
            featureVersion: 0,
            userId: "3",
            variationId: "",
            variationName: "",
            variationValue: true,
            reason: .client), BKTEvaluationDetails(
                featureId: "4",
                featureVersion: 0,
                userId: "3",
                variationId: "",
                variationName: "",
                variationValue: false,
                reason: .client))

        XCTAssertEqual(BKTEvaluationDetails(
            featureId: "5",
            featureVersion: 0,
            userId: "3",
            variationId: "",
            variationName: "",
            variationValue: [
                "key1" : "value1",
                "key2" : "value2"
            ],
            reason: .client), BKTEvaluationDetails(
                featureId: "5",
                featureVersion: 0,
                userId: "3",
                variationId: "",
                variationName: "",
                variationValue: [
                    "key2" : "value2",
                    "key1" : "value1"
                ],
                reason: .client))

        XCTAssertNotEqual(BKTEvaluationDetails(
            featureId: "5",
            featureVersion: 0,
            userId: "3",
            variationId: "",
            variationName: "",
            variationValue: [
                "key1" : "value1",
                "key2" : "value2"
            ],
            reason: .client), BKTEvaluationDetails(
                featureId: "5",
                featureVersion: 0,
                userId: "3",
                variationId: "",
                variationName: "",
                variationValue: [
                    "key2" : "value2",
                    "key1" : "value1",
                    "key3" : "value3"
                ],
                reason: .client))
    }

    func testCreateDefaultInstance() throws {
        XCTAssertEqual(BKTEvaluationDetails<Int>.newDefaultInstance(featureId: "1", userId: "2", defaultValue: 2),
               BKTEvaluationDetails(
                featureId: "1",
                featureVersion: 0,
                userId: "2",
                variationId: "",
                variationName: "",
                variationValue: 2,
                reason: .client)
        )
        XCTAssertEqual(BKTEvaluationDetails<String>.newDefaultInstance(featureId: "2", userId: "3", defaultValue: "2"),
               BKTEvaluationDetails(
                featureId: "2",
                featureVersion: 0,
                userId: "3",
                variationId: "",
                variationName: "",
                variationValue: "2",
                reason: .client)
        )
        XCTAssertEqual(BKTEvaluationDetails<Double>.newDefaultInstance(featureId: "1", userId: "2", defaultValue: 2.0),
               BKTEvaluationDetails(
                featureId: "1",
                featureVersion: 0,
                userId: "2",
                variationId: "",
                variationName: "",
                variationValue: 2.0,
                reason: .client)
        )
        XCTAssertEqual(BKTEvaluationDetails<Bool>.newDefaultInstance(featureId: "11", userId: "22", defaultValue: true),
               BKTEvaluationDetails(
                featureId: "11",
                featureVersion: 0,
                userId: "22",
                variationId: "",
                variationName: "",
                variationValue: true,
                reason: .client)
        )
        XCTAssertEqual(BKTEvaluationDetails<[String: AnyHashable]>.newDefaultInstance(featureId: "11", userId: "22", defaultValue: ["key":"value"]),
               BKTEvaluationDetails(
                featureId: "11",
                featureVersion: 0,
                userId: "22",
                variationId: "",
                variationName: "",
                variationValue: ["key":"value"],
                reason: .client)
        )
    }
}
// swiftlint:enable function_body_length
