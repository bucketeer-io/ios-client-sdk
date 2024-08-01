import Foundation
import XCTest
@testable import Bucketeer

final class BKTValueTests: XCTestCase {

    func testDecodeString() throws {
        let json = "\"test string\""
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(BKTValue.self, from: data)
        XCTAssertEqual(decoded, .string("test string"))
    }

    func testDecodeInteger() throws {
        let json = "123"
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(BKTValue.self, from: data)
        XCTAssertEqual(decoded, .integer(123))
    }

    func testDecodeDouble() throws {
        let json = "123.456"
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(BKTValue.self, from: data)
        XCTAssertEqual(decoded, .double(123.456))
    }

    func testDecodeBoolean() throws {
        let json = "true"
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(BKTValue.self, from: data)
        XCTAssertEqual(decoded, .boolean(true))
    }

    func testDecodeDictionary() throws {
        let json = "{\"key\": \"value\"}"
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(BKTValue.self, from: data)
        XCTAssertEqual(decoded, .dictionary(["key": .string("value")]))
    }

    func testDecodeList() throws {
        let json = "[\"value1\", \"value2\"]"
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(BKTValue.self, from: data)
        XCTAssertEqual(decoded, .list([.string("value1"), .string("value2")]))
    }

    func testDecodeNull() throws {
        let json = "null"
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(BKTValue.self, from: data)
        XCTAssertEqual(decoded, .null)
    }

    func testEncodeString() throws {
        let value = BKTValue.string("test string")
        let encoded = try JSONEncoder().encode(value)
        let jsonString = String(data: encoded, encoding: .utf8)!
        XCTAssertEqual(jsonString, "\"test string\"")
    }

    func testEncodeInteger() throws {
        let value = BKTValue.integer(123)
        let encoded = try JSONEncoder().encode(value)
        let jsonString = String(data: encoded, encoding: .utf8)!
        XCTAssertEqual(jsonString, "123")
    }

    func testEncodeDouble() throws {
        let value = BKTValue.double(123.456)
        let encoded = try JSONEncoder().encode(value)
        let jsonString = String(data: encoded, encoding: .utf8)!
        XCTAssertEqual(jsonString, "123.456")
    }

    func testEncodeBoolean() throws {
        let value = BKTValue.boolean(true)
        let encoded = try JSONEncoder().encode(value)
        let jsonString = String(data: encoded, encoding: .utf8)!
        XCTAssertEqual(jsonString, "true")
    }

    func testEncodeDictionary() throws {
        let value = BKTValue.dictionary(["key": .string("value")])
        let encoded = try JSONEncoder().encode(value)
        let jsonString = String(data: encoded, encoding: .utf8)!
        XCTAssertEqual(jsonString, "{\"key\":\"value\"}")
    }

    func testEncodeList() throws {
        let value = BKTValue.list([.string("value1"), .string("value2")])
        let encoded = try JSONEncoder().encode(value)
        let jsonString = String(data: encoded, encoding: .utf8)!
        XCTAssertEqual(jsonString, "[\"value1\",\"value2\"]")
    }

    func testEncodeNull() throws {
        let value = BKTValue.null
        let encoded = try JSONEncoder().encode(value)
        let jsonString = String(data: encoded, encoding: .utf8)!
        XCTAssertEqual(jsonString, "null")
    }

    func testAsBoolean() {
        XCTAssertEqual(BKTValue.boolean(true).asBoolean(), true)
        XCTAssertNil(BKTValue.string("string").asBoolean())
        XCTAssertNil(BKTValue.integer(123).asBoolean())
        XCTAssertNil(BKTValue.double(123.456).asBoolean())
        XCTAssertNil(BKTValue.list([.boolean(true)]).asBoolean())
        XCTAssertNil(BKTValue.dictionary(["key": .boolean(true)]).asBoolean())
        XCTAssertNil(BKTValue.null.asBoolean())
    }

    func testAsString() {
        XCTAssertEqual(BKTValue.string("test").asString(), "test")
        XCTAssertNil(BKTValue.boolean(true).asString())
        XCTAssertNil(BKTValue.integer(123).asString())
        XCTAssertNil(BKTValue.double(123.456).asString())
        XCTAssertNil(BKTValue.list([.string("value")]).asString())
        XCTAssertNil(BKTValue.dictionary(["key": .string("value")]).asString())
        XCTAssertNil(BKTValue.null.asString())
    }

    func testAsInteger() {
        XCTAssertEqual(BKTValue.integer(123).asInteger(), 123)
        XCTAssertNil(BKTValue.boolean(true).asInteger())
        XCTAssertNil(BKTValue.string("string").asInteger())
        XCTAssertNil(BKTValue.double(123.456).asInteger())
        XCTAssertNil(BKTValue.list([.integer(123)]).asInteger())
        XCTAssertNil(BKTValue.dictionary(["key": .integer(123)]).asInteger())
        XCTAssertNil(BKTValue.null.asInteger())
    }

    func testAsDouble() {
        XCTAssertEqual(BKTValue.double(123.456).asDouble(), 123.456)
        XCTAssertNil(BKTValue.boolean(true).asDouble())
        XCTAssertNil(BKTValue.string("string").asDouble())
        XCTAssertNil(BKTValue.integer(123).asDouble())
        XCTAssertNil(BKTValue.list([.double(123.456)]).asDouble())
        XCTAssertNil(BKTValue.dictionary(["key": .double(123.456)]).asDouble())
        XCTAssertNil(BKTValue.null.asDouble())
    }

    func testAsList() {
        XCTAssertEqual(BKTValue.list([.string("value")]).asList(), [.string("value")])
        XCTAssertNil(BKTValue.boolean(true).asList())
        XCTAssertNil(BKTValue.string("string").asList())
        XCTAssertNil(BKTValue.integer(123).asList())
        XCTAssertNil(BKTValue.double(123.456).asList())
        XCTAssertNil(BKTValue.dictionary(["key": .list([.string("value")])]).asList())
        XCTAssertNil(BKTValue.null.asList())
    }

    func testAsDictionary() {
        XCTAssertEqual(BKTValue.dictionary(["key": .string("value")]).asDictionary(), ["key": .string("value")])
        XCTAssertNil(BKTValue.boolean(true).asDictionary())
        XCTAssertNil(BKTValue.string("string").asDictionary())
        XCTAssertNil(BKTValue.integer(123).asDictionary())
        XCTAssertNil(BKTValue.double(123.456).asDictionary())
        XCTAssertNil(BKTValue.list([.dictionary(["key": .string("value")])]).asDictionary())
        XCTAssertNil(BKTValue.null.asDictionary())
    }

    func testDecodeJsonString() throws {
        XCTAssertEqual("".getVariationBKTValue(logger: nil), .string(""))
        XCTAssertEqual("test".getVariationBKTValue(logger: nil), .string("test"))
        XCTAssertEqual("true".getVariationBKTValue(logger: nil), .boolean(true))
        XCTAssertEqual("false".getVariationBKTValue(logger: nil), .boolean(false))
        XCTAssertEqual("1".getVariationBKTValue(logger: nil), .integer(1))
        XCTAssertEqual("1.2".getVariationBKTValue(logger: nil), .double(1.2))

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
                    .dictionary(["key" : .integer(10)])
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
                    .integer(1),
                    .double(2.2),
                    .boolean(true)
                ]
            )
        )
    }
}
