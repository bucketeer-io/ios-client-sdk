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
            variation: .init(
                id: "variation",
                value: value,
                name: nil,
                description: nil
            ),
            reason: .init(type: .default),
            variationValue: value
        )
    }

    func testGetVariationValueAsText() {
        let value: String = mockEvaluation(value: "text").getVariationValue(defaultValue: "default", logger: nil)
        XCTAssertEqual(value, "text")
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
}
