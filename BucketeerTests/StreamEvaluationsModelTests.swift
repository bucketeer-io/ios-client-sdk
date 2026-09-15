import XCTest
@testable import Bucketeer

final class StreamEvaluationsModelTests: XCTestCase {

    // MARK: - StreamEvaluationsRequestBody

    func testRequestBodyEncoding() throws {
        let body = StreamEvaluationsRequestBody(
            tag: "tag1",
            user: User(id: "user1", data: ["age": "28"]),
            sourceId: .ios,
            sdkVersion: "12.3.5",
            userEvaluationsId: "",
            evaluatedAt: "0"
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(body)
        let jsonString = String(data: data, encoding: .utf8) ?? ""

        let expected = """
{
  "evaluatedAt" : "0",
  "sdkVersion" : "12.3.5",
  "sourceId" : 2,
  "tag" : "tag1",
  "user" : {
    "data" : {
      "age" : "28"
    },
    "id" : "user1"
  },
  "userEvaluationsId" : ""
}
"""
        XCTAssertEqual(jsonString, expected)
    }

    func testRequestBodyEncodingCarriesLastKnownState() throws {
        let body = StreamEvaluationsRequestBody(
            tag: "tag1",
            user: User(id: "user1", data: [:]),
            sourceId: .ios,
            sdkVersion: "12.3.5",
            userEvaluationsId: "evaluations_id_1",
            evaluatedAt: "1700000000"
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(body)
        let decoded = try JSONDecoder().decode(StreamEvaluationsRequestBody.self, from: data)
        XCTAssertEqual(decoded.userEvaluationsId, "evaluations_id_1")
        XCTAssertEqual(decoded.evaluatedAt, "1700000000")
    }

    // MARK: - StreamEvaluationsEvent (put/patch payload)

    private func decodeEvent(_ json: String) throws -> StreamEvaluationsEvent {
        try JSONDecoder().decode(StreamEvaluationsEvent.self, from: Data(json.utf8))
    }

    func testDecodesRealisticBackendPayload() throws {
        // Written by protojson with EmitUnpopulated: true, so every field is present,
        // including an extra top-level "state" key this model doesn't map, and an extra
        // "variation" object nested inside an evaluation.
        let json = """
        {
            "userEvaluationsId": "user_evaluation_id_1",
            "evaluations": {
                "id": "",
                "state": "FULL",
                "evaluations": [
                    {
                        "id": "feature1:1:user1",
                        "featureId": "feature1",
                        "featureVersion": 1,
                        "userId": "user1",
                        "variationId": "variation1",
                        "variationName": "variation name1",
                        "variationValue": "value1",
                        "variation": { "id": "variation1", "value": "value1" },
                        "reason": { "type": "DEFAULT", "ruleId": "" }
                    }
                ],
                "createdAt": "1700000000",
                "archivedFeatureIds": [],
                "forceUpdate": false
            }
        }
        """
        let event = try decodeEvent(json)
        XCTAssertEqual(event.userEvaluationsId, "user_evaluation_id_1")
        XCTAssertEqual(event.evaluations.id, "")
        XCTAssertEqual(event.evaluations.createdAt, "1700000000")
        XCTAssertEqual(event.evaluations.forceUpdate, false)
        XCTAssertEqual(event.evaluations.archivedFeatureIds, [])
        XCTAssertEqual(event.evaluations.evaluations.count, 1)
        XCTAssertEqual(event.evaluations.evaluations.first?.featureId, "feature1")
        XCTAssertEqual(event.evaluations.evaluations.first?.variationValue, "value1")
    }

    func testToGetEvaluationsResponseMapsEveryField() throws {
        let json = """
        {
            "userEvaluationsId": "ueid1",
            "evaluations": {
                "id": "ueid1",
                "evaluations": [],
                "createdAt": "1700000001",
                "archivedFeatureIds": ["archived1"],
                "forceUpdate": true
            }
        }
        """
        let event = try decodeEvent(json)
        let response = event.toGetEvaluationsResponse()
        XCTAssertEqual(response.userEvaluationsId, "ueid1")
        XCTAssertEqual(response.evaluations.id, "ueid1")
        XCTAssertEqual(response.evaluations.createdAt, "1700000001")
        XCTAssertEqual(response.evaluations.forceUpdate, true)
        XCTAssertEqual(response.evaluations.archivedFeatureIds, ["archived1"])
        XCTAssertEqual(response.evaluations.evaluations, [])
    }

    /// The backend may omit zero-valued fields when marshaling. The shape check must
    /// accept the omission so a patch isn't silently dropped, matching the REST path's
    /// existing tolerance (`GetEvaluationsResponse` decodes the same way).
    func testMissingOptionalFieldsDefaultToEmptyValues() throws {
        let json = """
        {
            "userEvaluationsId": "ueid1",
            "evaluations": {
                "createdAt": "1700000000"
            }
        }
        """
        let event = try decodeEvent(json)
        XCTAssertEqual(event.evaluations.id, "")
        XCTAssertEqual(event.evaluations.forceUpdate, false)
        XCTAssertEqual(event.evaluations.evaluations, [])
        XCTAssertEqual(event.evaluations.archivedFeatureIds, [])
    }

    // MARK: - Rejected payloads

    func testRejectsPayloadsWithWrongOrMissingShape() {
        let badPayloads = [
            "{}",
            "{\"userEvaluationsId\":\"x\"}", // missing evaluations
            "{\"userEvaluationsId\":42,\"evaluations\":{\"createdAt\":\"1\"}}", // wrong type
            "{\"userEvaluationsId\":\"x\",\"evaluations\":null}", // evaluations not an object
            "{\"userEvaluationsId\":\"x\",\"evaluations\":{\"forceUpdate\":false}}", // missing createdAt
            "{\"userEvaluationsId\":\"x\",\"evaluations\":{\"createdAt\":1700000000}}", // createdAt is a number
            "[]",
            "null",
            "not-json"
        ]
        for payload in badPayloads {
            XCTAssertThrowsError(try decodeEvent(payload), "payload: \(payload)")
        }
    }

    /// iOS-specific, stricter than the JS SDK on purpose: JS only checks that createdAt is a
    /// string, so a non-numeric value like "abc" passes there and becomes evaluatedAt in
    /// storage. The stale-write guard (added in a later PR) compares evaluatedAt as a number,
    /// so an unreadable value would silently disable that guard for every later write. This
    /// SDK rejects the event instead.
    func testRejectsNonNumericCreatedAt() {
        let badPayloads = [
            "{\"userEvaluationsId\":\"x\",\"evaluations\":{\"createdAt\":\"abc\"}}",
            "{\"userEvaluationsId\":\"x\",\"evaluations\":{\"createdAt\":\"\"}}"
        ]
        for payload in badPayloads {
            XCTAssertThrowsError(try decodeEvent(payload), "payload: \(payload)")
        }
    }

    // MARK: - StreamErrorEvent

    func testDecodesErrorEventPayload() throws {
        let json = """
        { "code": "INTERNAL", "message": "evaluation failed" }
        """
        let event = try JSONDecoder().decode(StreamErrorEvent.self, from: Data(json.utf8))
        XCTAssertEqual(event.code, "INTERNAL")
        XCTAssertEqual(event.message, "evaluation failed")
    }

    func testErrorEventPayloadWithMissingFieldsDecodesWithNils() throws {
        let event = try JSONDecoder().decode(StreamErrorEvent.self, from: Data("{}".utf8))
        XCTAssertNil(event.code)
        XCTAssertNil(event.message)
    }
}
