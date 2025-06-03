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
                        reason: .errorException), BKTEvaluationDetails(
                            featureId: "1",
                            featureVersion: 0,
                            userId: "2",
                            variationId: "",
                            variationName: "",
                            variationValue: 2,
                            reason: .errorException))
        XCTAssertNotEqual(BKTEvaluationDetails(
                            featureId: "1",
                            featureVersion: 0,
                            userId: "2",
                            variationId: "",
                            variationName: "",
                            variationValue: 2,
                            reason: .errorException), BKTEvaluationDetails(
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
                        reason: .errorException), BKTEvaluationDetails(
                            featureId: "2",
                            featureVersion: 0,
                            userId: "3",
                            variationId: "",
                            variationName: "",
                            variationValue: "2",
                            reason: .errorException))
        XCTAssertNotEqual(BKTEvaluationDetails(
                            featureId: "2",
                            featureVersion: 0,
                            userId: "3",
                            variationId: "",
                            variationName: "",
                            variationValue: "2",
                            reason: .errorException), BKTEvaluationDetails(
                                featureId: "2",
                                featureVersion: 0,
                                userId: "3",
                                variationId: "",
                                variationName: "",
                                variationValue: "22",
                                reason: .errorWrongType))

        XCTAssertEqual(BKTEvaluationDetails(
                        featureId: "3",
                        featureVersion: 0,
                        userId: "3",
                        variationId: "",
                        variationName: "",
                        variationValue: 3.0,
                        reason: .errorException), BKTEvaluationDetails(
                            featureId: "3",
                            featureVersion: 0,
                            userId: "3",
                            variationId: "",
                            variationName: "",
                            variationValue: 3.0,
                            reason: .errorException))

        XCTAssertNotEqual(BKTEvaluationDetails(
                            featureId: "3",
                            featureVersion: 0,
                            userId: "3",
                            variationId: "",
                            variationName: "",
                            variationValue: 3.0,
                            reason: .errorException), BKTEvaluationDetails(
                                featureId: "3",
                                featureVersion: 1,
                                userId: "3",
                                variationId: "",
                                variationName: "",
                                variationValue: 3.1,
                                reason: .errorUserIdNotSpecified))

        XCTAssertEqual(BKTEvaluationDetails(
                        featureId: "4",
                        featureVersion: 0,
                        userId: "3",
                        variationId: "",
                        variationName: "",
                        variationValue: true,
                        reason: .errorException), BKTEvaluationDetails(
                            featureId: "4",
                            featureVersion: 0,
                            userId: "3",
                            variationId: "",
                            variationName: "",
                            variationValue: true,
                            reason: .errorException))

        XCTAssertNotEqual(BKTEvaluationDetails(
                            featureId: "4",
                            featureVersion: 0,
                            userId: "3",
                            variationId: "",
                            variationName: "",
                            variationValue: true,
                            reason: .errorException), BKTEvaluationDetails(
                                featureId: "4",
                                featureVersion: 0,
                                userId: "3",
                                variationId: "",
                                variationName: "",
                                variationValue: false,
                                reason: .errorNoEvaluations))

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
                        reason: .errorException), BKTEvaluationDetails(
                            featureId: "5",
                            featureVersion: 0,
                            userId: "3",
                            variationId: "",
                            variationName: "",
                            variationValue: [
                                "key2" : "value2",
                                "key1" : "value1"
                            ],
                            reason: .errorException))

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
                            reason: .errorException), BKTEvaluationDetails(
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
                                reason: .errorUserIdNotSpecified))
    }

    func testCreateDefaultInstance() throws {
        XCTAssertEqual(BKTEvaluationDetails<Int>.newDefaultInstance(featureId: "1", userId: "2", defaultValue: 2, reason: .default),
                       BKTEvaluationDetails(
                        featureId: "1",
                        featureVersion: 0,
                        userId: "2",
                        variationId: "",
                        variationName: "",
                        variationValue: 2,
                        reason: .default)
        )
        XCTAssertEqual(BKTEvaluationDetails<String>.newDefaultInstance(featureId: "2", userId: "3", defaultValue: "2", reason: .default),
                       BKTEvaluationDetails(
                        featureId: "2",
                        featureVersion: 0,
                        userId: "3",
                        variationId: "",
                        variationName: "",
                        variationValue: "2",
                        reason: .default)
        )
        XCTAssertEqual(BKTEvaluationDetails<Double>.newDefaultInstance(featureId: "1", userId: "2", defaultValue: 2.0, reason: .errorException),
                       BKTEvaluationDetails(
                        featureId: "1",
                        featureVersion: 0,
                        userId: "2",
                        variationId: "",
                        variationName: "",
                        variationValue: 2.0,
                        reason: .errorException)
        )
        XCTAssertEqual(BKTEvaluationDetails<Bool>.newDefaultInstance(featureId: "11", userId: "22", defaultValue: true, reason: .errorFeatureFlagIdNotSpecified),
                       BKTEvaluationDetails(
                        featureId: "11",
                        featureVersion: 0,
                        userId: "22",
                        variationId: "",
                        variationName: "",
                        variationValue: true,
                        reason: .errorFeatureFlagIdNotSpecified)
        )
        XCTAssertEqual(BKTEvaluationDetails<[String: AnyHashable]>.newDefaultInstance(featureId: "11", userId: "22", defaultValue: ["key":"value"], reason: .errorNoEvaluations),
                       BKTEvaluationDetails(
                        featureId: "11",
                        featureVersion: 0,
                        userId: "22",
                        variationId: "",
                        variationName: "",
                        variationValue: ["key":"value"],
                        reason: .errorNoEvaluations)
        )
    }

    func testFromStringWithValidValues() {
        XCTAssertEqual(BKTEvaluationDetails<String>.Reason.fromString(value: "TARGET"), .target)
        XCTAssertEqual(BKTEvaluationDetails<Bool>.Reason.fromString(value: "RULE"), .rule)
        XCTAssertEqual(BKTEvaluationDetails<Int>.Reason.fromString(value: "DEFAULT"), .default)
        XCTAssertEqual(BKTEvaluationDetails<Double>.Reason.fromString(value: "CLIENT"), .client)
        XCTAssertEqual(BKTEvaluationDetails<Bool>.Reason.fromString(value: "OFF_VARIATION"), .offVariation)
        XCTAssertEqual(BKTEvaluationDetails<Int>.Reason.fromString(value: "PREREQUISITE"), .prerequisite)
        XCTAssertEqual(BKTEvaluationDetails<Double>.Reason.fromString(value: "ERROR_USER_ID_NOT_SPECIFIED"), .errorUserIdNotSpecified)
        XCTAssertEqual(BKTEvaluationDetails<Bool>.Reason.fromString(value: "ERROR_NO_EVALUATIONS"), .errorNoEvaluations)
        XCTAssertEqual(BKTEvaluationDetails<Int>.Reason.fromString(value: "ERROR_FEATURE_FLAG_ID_NOT_SPECIFIED"), .errorFeatureFlagIdNotSpecified)
        XCTAssertEqual(BKTEvaluationDetails<Double>.Reason.fromString(value: "ERROR_WRONG_TYPE"), .errorWrongType)
        XCTAssertEqual(BKTEvaluationDetails<Bool>.Reason.fromString(value: "ERROR_EXCEPTION"), .errorException)
        XCTAssertEqual(BKTEvaluationDetails<Bool>.Reason.fromString(value: "ERROR_FLAG_NOT_FOUND"), .errorFlagNotFound)
    }

    func testFromStringWithInvalidValue() {
        XCTAssertEqual(BKTEvaluationDetails<Int>.Reason.fromString(value: "INVALID"), .errorException)
    }
}
// swiftlint:enable function_body_length
