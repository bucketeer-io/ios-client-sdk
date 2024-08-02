import XCTest
@testable import Bucketeer

final class EvaluationTests: XCTestCase {

    func mockEvaluation(value: String) -> Evaluation {
        return Evaluation(
            id: "id",
            featureId: "feature",
            featureVersion: 1,
            userId: "user",
            variationId: "variation",
            variationName: "variation name",
            variationValue: value,
            reason: .init(type: .default)
        )
    }

    func testGetVariationValueAsText() {
        let value: String = mockEvaluation(value: "text").getVariationValue(defaultValue: "default", logger: nil)
        XCTAssertEqual(value, "text")
        let value123: String = mockEvaluation(value: "123").getVariationValue(defaultValue: "default", logger: nil)
        XCTAssertEqual(value123, "123")
    }

    func testGetVariationValueAsInt() {
        let value1: Int = mockEvaluation(value: "100").getVariationValue(defaultValue: 0, logger: nil)
        XCTAssertEqual(value1, 100)
        let value2: Int = mockEvaluation(value: "200.1").getVariationValue(defaultValue: 0, logger: nil)
        XCTAssertEqual(value2, 0)
        let value3: Int = mockEvaluation(value: "text").getVariationValue(defaultValue: 0, logger: nil)
        XCTAssertEqual(value3, 0)
    }

    func testGetVariationValueAsDouble() {
        let value1: Double = mockEvaluation(value: "100.1").getVariationValue(defaultValue: 0.0, logger: nil)
        XCTAssertEqual(value1, 100.1)
        let value2: Double = mockEvaluation(value: "200").getVariationValue(defaultValue: 0.0, logger: nil)
        XCTAssertEqual(value2, 200)
        let value3: Double = mockEvaluation(value: "text").getVariationValue(defaultValue: 0.0, logger: nil)
        XCTAssertEqual(value3, 0)
    }

    func testGetVariationValueAsBool() {
        let value1: Bool = mockEvaluation(value: "true").getVariationValue(defaultValue: false, logger: nil)
        XCTAssertEqual(value1, true)
        let value2: Bool = mockEvaluation(value: "false").getVariationValue(defaultValue: true, logger: nil)
        XCTAssertEqual(value2, false)
        let value3: Bool = mockEvaluation(value: "text").getVariationValue(defaultValue: false, logger: nil)
        XCTAssertEqual(value3, false)
    }

    func testGetVariationValueAsAny() throws {
        struct Some: Equatable, Codable {
            let value: String
        }
        let object = Some(value: "text")
        let jsonString = object.value.data(using: .utf8)?.base64EncodedString() ?? ""
        let value: Any = mockEvaluation(value: jsonString).getVariationValue(defaultValue: "", logger: nil)
        XCTAssertEqual(value as? String, jsonString)
    }

    func testGetVariationValueAsBKTValue() throws {
        let boolValue: BKTValue? = mockEvaluation(value: "true").getVariationValue(logger: nil)
        XCTAssertEqual(boolValue, .boolean(true))
        let stringValue: BKTValue? = mockEvaluation(value: "a123").getVariationValue(logger: nil)
        XCTAssertEqual(stringValue, .string("a123"))
        // "123" in JSON is a integer 123
        let intValue: BKTValue? = mockEvaluation(value: "123").getVariationValue(logger: nil)
        XCTAssertEqual(intValue, .integer(123))
        let doubleValue: BKTValue? = mockEvaluation(value: "1.2").getVariationValue(logger: nil)
        XCTAssertEqual(doubleValue, .double(1.2))

        let objectValue: BKTValue = Evaluation.jsonObjectEvaluation.getVariationValue(defaultValue: .boolean(false), logger: nil)
        XCTAssertEqual(
            objectValue,
            .dictionary(
                [
                    "value": .string("body"),
                    "value1": .string("body1"),
                    "valueInt" : .integer(1),
                    "valueBool" : .boolean(true),
                    "valueDouble" : .double(1.2),
                    "valueDictionary": .dictionary(["key" : .string("value")]),
                    "valueList1": .list(
                        [
                            .dictionary(["key" : .string("value")]),
                            .dictionary(["key" : .integer(10)])
                        ]
                    ),
                    "valueList2": .list(
                        [
                            .integer(1),
                            .double(2.2),
                            .boolean(true)
                        ]
                    )
                ]
            )
        )
    }
}
