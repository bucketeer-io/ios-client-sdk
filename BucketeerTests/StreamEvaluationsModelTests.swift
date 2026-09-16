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

    // MARK: - put/patch payload: reuses GetEvaluationsResponse (no separate stream type)
    //
    // The SSE `put`/`patch` payload and the polling `get_evaluations` response have the
    // identical wire shape: {"userEvaluationsId": ..., "evaluations": {...}}, both wrapping
    // the same backend `feature.UserEvaluations` message. So there is no dedicated
    // "StreamEvaluationsEvent" type here: the stream decodes straight into the existing
    // `GetEvaluationsResponse`, the same type ApiClientImpl already uses for polling. The
    // test below exists to lock in that shared-shape assumption (in particular, that an
    // extra key the stream doesn't carry, like a nested "variation" object, is harmlessly
    // ignored) so a future backend change that breaks it is caught here.

    private func decodeResponse(_ json: String) throws -> GetEvaluationsResponse {
        try JSONDecoder().decode(GetEvaluationsResponse.self, from: Data(json.utf8))
    }

    func testGetEvaluationsResponseDecodesRealisticStreamPayload() throws {
        let json = """
        {
            "userEvaluationsId": "user_evaluation_id_1",
            "evaluations": {
                "id": "",
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
        let response = try decodeResponse(json)
        XCTAssertEqual(response.userEvaluationsId, "user_evaluation_id_1")
        XCTAssertEqual(response.evaluations.id, "")
        XCTAssertEqual(response.evaluations.createdAt, "1700000000")
        XCTAssertEqual(response.evaluations.forceUpdate, false)
        XCTAssertEqual(response.evaluations.archivedFeatureIds, [])
        XCTAssertEqual(response.evaluations.evaluations.count, 1)
        XCTAssertEqual(response.evaluations.evaluations.first?.featureId, "feature1")
        XCTAssertEqual(response.evaluations.evaluations.first?.variationValue, "value1")
    }

    /// Not new decode logic of ours, this is `GetEvaluationsResponse`'s existing (strict,
    /// unmodified) behavior. Pinned here because the stream path now depends on that
    /// strictness: if the backend ever sends a `put`/`patch` payload with a required field
    /// missing, the event is dropped rather than partially applied.
    func testGetEvaluationsResponseRejectsWrongOrMissingShape() {
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
            XCTAssertThrowsError(try decodeResponse(payload), "payload: \(payload)")
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
