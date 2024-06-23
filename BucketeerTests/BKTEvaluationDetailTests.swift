import XCTest
@testable import Bucketeer

// swiftlint:disable function_body_length
final class BKTEvaluationDetailTests: XCTestCase {

    func testEqualable() throws {
        XCTAssertEqual(BKTEvaluationDetail(
            featureId: "1",
            featureVersion: 0,
            userId: "2",
            variationId: "",
            variationName: "",
            variationValue: 2,
            reason: .client), BKTEvaluationDetail(
                featureId: "1",
                featureVersion: 0,
                userId: "2",
                variationId: "",
                variationName: "",
                variationValue: 2,
                reason: .client))
        XCTAssertNotEqual(BKTEvaluationDetail(
            featureId: "1",
            featureVersion: 0,
            userId: "2",
            variationId: "",
            variationName: "",
            variationValue: 2,
            reason: .client), BKTEvaluationDetail(
                featureId: "12",
                featureVersion: 0,
                userId: "2",
                variationId: "",
                variationName: "",
                variationValue: 2,
                reason: .default))

        XCTAssertEqual(BKTEvaluationDetail(
            featureId: "2",
            featureVersion: 0,
            userId: "3",
            variationId: "",
            variationName: "",
            variationValue: "2",
            reason: .client), BKTEvaluationDetail(
                featureId: "2",
                featureVersion: 0,
                userId: "3",
                variationId: "",
                variationName: "",
                variationValue: "2",
                reason: .client))
        XCTAssertNotEqual(BKTEvaluationDetail(
            featureId: "2",
            featureVersion: 0,
            userId: "3",
            variationId: "",
            variationName: "",
            variationValue: "2",
            reason: .client), BKTEvaluationDetail(
                featureId: "2",
                featureVersion: 0,
                userId: "3",
                variationId: "",
                variationName: "",
                variationValue: "22",
                reason: .client))

        XCTAssertEqual(BKTEvaluationDetail(
            featureId: "3",
            featureVersion: 0,
            userId: "3",
            variationId: "",
            variationName: "",
            variationValue: 3.0,
            reason: .client), BKTEvaluationDetail(
                featureId: "3",
                featureVersion: 0,
                userId: "3",
                variationId: "",
                variationName: "",
                variationValue: 3.0,
                reason: .client))

        XCTAssertNotEqual(BKTEvaluationDetail(
            featureId: "3",
            featureVersion: 0,
            userId: "3",
            variationId: "",
            variationName: "",
            variationValue: 3.0,
            reason: .client), BKTEvaluationDetail(
                featureId: "3",
                featureVersion: 1,
                userId: "3",
                variationId: "",
                variationName: "",
                variationValue: 3.1,
                reason: .client))

        XCTAssertEqual(BKTEvaluationDetail(
            featureId: "4",
            featureVersion: 0,
            userId: "3",
            variationId: "",
            variationName: "",
            variationValue: true,
            reason: .client), BKTEvaluationDetail(
                featureId: "4",
                featureVersion: 0,
                userId: "3",
                variationId: "",
                variationName: "",
                variationValue: true,
                reason: .client))

        XCTAssertNotEqual(BKTEvaluationDetail(
            featureId: "4",
            featureVersion: 0,
            userId: "3",
            variationId: "",
            variationName: "",
            variationValue: true,
            reason: .client), BKTEvaluationDetail(
                featureId: "4",
                featureVersion: 0,
                userId: "3",
                variationId: "",
                variationName: "",
                variationValue: false,
                reason: .client))

        XCTAssertEqual(BKTEvaluationDetail(
            featureId: "5",
            featureVersion: 0,
            userId: "3",
            variationId: "",
            variationName: "",
            variationValue: [
                "key1" : "value1",
                "key2" : "value2"
            ],
            reason: .client), BKTEvaluationDetail(
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

        XCTAssertNotEqual(BKTEvaluationDetail(
            featureId: "5",
            featureVersion: 0,
            userId: "3",
            variationId: "",
            variationName: "",
            variationValue: [
                "key1" : "value1",
                "key2" : "value2"
            ],
            reason: .client), BKTEvaluationDetail(
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
        XCTAssertEqual(BKTEvaluationDetail<Int>.newDefaultInstance(featureId: "1", userId: "2", defaultValue: 2),
               BKTEvaluationDetail(
                featureId: "1",
                featureVersion: 0,
                userId: "2",
                variationId: "",
                variationName: "",
                variationValue: 2,
                reason: .client)
        )
        XCTAssertEqual(BKTEvaluationDetail<String>.newDefaultInstance(featureId: "2", userId: "3", defaultValue: "2"),
               BKTEvaluationDetail(
                featureId: "2",
                featureVersion: 0,
                userId: "3",
                variationId: "",
                variationName: "",
                variationValue: "2",
                reason: .client)
        )
        XCTAssertEqual(BKTEvaluationDetail<Double>.newDefaultInstance(featureId: "1", userId: "2", defaultValue: 2.0),
               BKTEvaluationDetail(
                featureId: "1",
                featureVersion: 0,
                userId: "2",
                variationId: "",
                variationName: "",
                variationValue: 2.0,
                reason: .client)
        )
        XCTAssertEqual(BKTEvaluationDetail<Bool>.newDefaultInstance(featureId: "11", userId: "22", defaultValue: true),
               BKTEvaluationDetail(
                featureId: "11",
                featureVersion: 0,
                userId: "22",
                variationId: "",
                variationName: "",
                variationValue: true,
                reason: .client)
        )
        XCTAssertEqual(BKTEvaluationDetail<[String: AnyHashable]>.newDefaultInstance(featureId: "11", userId: "22", defaultValue: ["key":"value"]),
               BKTEvaluationDetail(
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
