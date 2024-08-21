import Foundation
import XCTest
@testable import Bucketeer

class JSONSerializationTests: XCTestCase {

    func testJSONSerializationRemoveTrailingZeroesFromDoubles() {
        // Given
        let jsonObject: [String: Any] = ["value": 1.0]

        // When
        let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted)
        let jsonString = String(data: jsonData!, encoding: .utf8)

        // Then
        let expectedJsonString = "{\n  \"value\" : 1\n}"
        XCTAssertEqual(jsonString, expectedJsonString)
    }
}

class BKTValueEncodingTests: XCTestCase {

    struct EncodeTestCase {
        let value: BKTValue
        let expectedJsonString: String
    }

    let testCases: [EncodeTestCase] = [
        EncodeTestCase(value: .string("test string"), expectedJsonString: "\"test string\""),
        EncodeTestCase(value: .string(""), expectedJsonString: "\"\""),
        EncodeTestCase(value: .number(123), expectedJsonString: "123"),
        EncodeTestCase(value: .number(123.456), expectedJsonString: "123.456"),
        EncodeTestCase(value: .number(123.0), expectedJsonString: "123"),
        EncodeTestCase(value: .boolean(true), expectedJsonString: "true"),
        EncodeTestCase(value: .dictionary(["key": .string("value")]), expectedJsonString: "{\"key\":\"value\"}"),
        EncodeTestCase(value: .list([.string("value1"), .string("value2")]), expectedJsonString: "[\"value1\",\"value2\"]"),
        EncodeTestCase(value: .null, expectedJsonString: "null")
    ]

    func testEncode() throws {
        for testCase in testCases {
            let encoded = try JSONEncoder().encode(testCase.value)
            let jsonString = String(data: encoded, encoding: .utf8)!
            XCTAssertEqual(jsonString, testCase.expectedJsonString)
        }
    }
}

class BKTValueDecodeTests: XCTestCase {

    struct DecodeTestCase {
        let json: String
        let expected: BKTValue
    }

    func testDecode() throws {
        let testCases: [DecodeTestCase] = [
            DecodeTestCase(json: "\"test string\"", expected: .string("test string")),
            DecodeTestCase(json: "null", expected: .null),
            DecodeTestCase(json: "123", expected: .number(123)),
            DecodeTestCase(json: "123.456", expected: .number(123.456)),
            DecodeTestCase(json: "123.0", expected: .number(123)),
            DecodeTestCase(json: "123.00", expected: .number(123)),
            DecodeTestCase(json: "true", expected: .boolean(true)),
            DecodeTestCase(json: "false", expected: .boolean(false)),
            DecodeTestCase(json: "\"true\"", expected: .string("true")),
            DecodeTestCase(json: "{\"key\": \"value\"}", expected: .dictionary(["key": .string("value")]))
        ]

        for testCase in testCases {
            let data = testCase.json.data(using: .utf8)!
            let decoded = try JSONDecoder().decode(BKTValue.self, from: data)
            XCTAssertEqual(decoded, testCase.expected, "Failed to decode \(testCase.json)")
        }
    }

    func testDecodeEmptyString() throws {
        let jsonEmptyString = ""
        let dataEmptyString = jsonEmptyString.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(BKTValue.self, from: dataEmptyString))
    }

    func testDecodeInvalidString() throws {
        let jsonInvalidString = "test string"
        let dataInvalidString = jsonInvalidString.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(BKTValue.self, from: dataInvalidString))
    }
}

final class BKTValueTests: XCTestCase {
    func testAsBoolean() {
        XCTAssertEqual(BKTValue.boolean(true).asBoolean(), true)
        XCTAssertNil(BKTValue.string("string").asBoolean())
        XCTAssertNil(BKTValue.number(123).asBoolean())
        XCTAssertNil(BKTValue.number(123.456).asBoolean())
        XCTAssertNil(BKTValue.list([.boolean(true)]).asBoolean())
        XCTAssertNil(BKTValue.dictionary(["key": .boolean(true)]).asBoolean())
        XCTAssertNil(BKTValue.null.asBoolean())
    }

    func testAsString() {
        XCTAssertEqual(BKTValue.string("test").asString(), "test")
        XCTAssertNil(BKTValue.boolean(true).asString())
        XCTAssertNil(BKTValue.number(123).asString())
        XCTAssertNil(BKTValue.number(123.456).asString())
        XCTAssertNil(BKTValue.list([.string("value")]).asString())
        XCTAssertNil(BKTValue.dictionary(["key": .string("value")]).asString())
        XCTAssertNil(BKTValue.null.asString())
    }

    func testAsInteger() {
        XCTAssertEqual(BKTValue.number(123).asInteger(), 123)
        XCTAssertNil(BKTValue.boolean(true).asInteger())
        XCTAssertNil(BKTValue.string("string").asInteger())
        XCTAssertEqual(BKTValue.number(123.456).asInteger(), 123)
        XCTAssertNil(BKTValue.list([.number(123)]).asInteger())
        XCTAssertNil(BKTValue.dictionary(["key": .number(123)]).asInteger())
        XCTAssertNil(BKTValue.null.asInteger())
    }

    func testAsDouble() {
        XCTAssertEqual(BKTValue.number(123.456).asDouble(), 123.456)
        XCTAssertNil(BKTValue.boolean(true).asDouble())
        XCTAssertNil(BKTValue.string("string").asDouble())
        XCTAssertEqual(BKTValue.number(123).asDouble(), 123)
        XCTAssertNil(BKTValue.list([.number(123.456)]).asDouble())
        XCTAssertNil(BKTValue.dictionary(["key": .number(123.456)]).asDouble())
        XCTAssertNil(BKTValue.null.asDouble())
    }

    func testAsList() {
        XCTAssertEqual(BKTValue.list([.string("value")]).asList(), [.string("value")])
        XCTAssertNil(BKTValue.boolean(true).asList())
        XCTAssertNil(BKTValue.string("string").asList())
        XCTAssertNil(BKTValue.number(123).asList())
        XCTAssertNil(BKTValue.number(123.456).asList())
        XCTAssertNil(BKTValue.dictionary(["key": .list([.string("value")])]).asList())
        XCTAssertNil(BKTValue.null.asList())
    }

    func testAsDictionary() {
        XCTAssertEqual(
            BKTValue.dictionary(
                ["key": .string("value"), "key1": .number(1)]).asDictionary(), ["key": .string("value"), "key1": .number(1)])
        XCTAssertNil(BKTValue.boolean(true).asDictionary())
        XCTAssertNil(BKTValue.string("string").asDictionary())
        XCTAssertNil(BKTValue.number(123).asDictionary())
        XCTAssertNil(BKTValue.number(123.456).asDictionary())
        XCTAssertNil(BKTValue.list([.dictionary(["key": .string("value")])]).asDictionary())
        XCTAssertNil(BKTValue.null.asDictionary())
    }

    func testGetVariationBKTValue() throws {
        XCTAssertEqual("".getVariationBKTValue(logger: nil), .string(""))
        XCTAssertEqual("null".getVariationBKTValue(logger: nil), .string("null"))
        XCTAssertEqual("test".getVariationBKTValue(logger: nil), .string("test"))
        XCTAssertEqual("test value".getVariationBKTValue(logger: nil), .string("test value"))
        XCTAssertEqual("\"test value\"".getVariationBKTValue(logger: nil), .string("test value"))
        XCTAssertEqual("true".getVariationBKTValue(logger: nil), .boolean(true))
        XCTAssertEqual("false".getVariationBKTValue(logger: nil), .boolean(false))
        XCTAssertEqual("1".getVariationBKTValue(logger: nil), .number(1))
        XCTAssertEqual("1.0".getVariationBKTValue(logger: nil), .number(1))
        XCTAssertEqual("1.2".getVariationBKTValue(logger: nil), .number(1.2))
        XCTAssertEqual("1.234".getVariationBKTValue(logger: nil), .number(1.234))

        let dictionaryJSONText = """
{
  "value" : "body",
  "value1" : "body1",
  "valueInt" : 1,
  "valueBool" : true,
  "valueDouble" : 1.2,
  "valueDictionary": {"key" : "value"},
  "valueList1": [{"key" : "value"},{"key" : 10}],
  "valueList2": [1,2.2,true]
}
"""
        XCTAssertEqual(
            dictionaryJSONText.getVariationBKTValue(logger: nil),
            .dictionary(
                [
                    "value": .string("body"),
                    "value1": .string("body1"),
                    "valueInt" : .number(1),
                    "valueBool" : .boolean(true),
                    "valueDouble" : .number(1.2),
                    "valueDictionary": .dictionary(["key" : .string("value")]),
                    "valueList1": .list(
                        [
                            .dictionary(["key" : .string("value")]),
                            .dictionary(["key" : .number(10)])
                        ]
                    ),
                    "valueList2": .list(
                        [
                            .number(1),
                            .number(2.2),
                            .boolean(true)
                        ]
                    )
                ]
            )
        )

        let listJSON1Text = """
[
    {"key" : "value"},
    {"key" : 10}
]
"""
        XCTAssertEqual(
            listJSON1Text.getVariationBKTValue(logger: nil),
            .list(
                [
                    .dictionary(["key" : .string("value")]),
                    .dictionary(["key" : .number(10)])
                ]
            )
        )

        let listJSON2Text = """
  [1,2.2,true]
"""
        XCTAssertEqual(
            listJSON2Text.getVariationBKTValue(logger: nil),
            .list(
                [
                    .number(1),
                    .number(2.2),
                    .boolean(true)
                ]
            )
        )
    }
}
