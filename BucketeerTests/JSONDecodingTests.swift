import XCTest
@testable import Bucketeer

class JSONDecodingTests: XCTestCase {

    func testDecodingGoalEvent() throws {
        let json = """
{
    "id": "event_1",
    "type": 1,
    "event": {
        "timestamp": 1,
        "goalId": "goal_1",
        "userId": "user_1",
        "value": 2,
        "user": {
            "id": "user_1",
            "data": {
                "key_1": "value_1",
                "key_2": "value_2"
            }
        },
        "tag": "tag_1",
        "sourceId": 2
    }
}
"""
        guard let data = json.data(using: .utf8) else {
            XCTFail("json is invalid")
            return
        }
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Event.self, from: data)
        XCTAssertEqual(decoded.id, "event_1")
        XCTAssertEqual(decoded.type, .goal)
        guard case .goal(let eventData) = decoded.event else {
            XCTFail("eventData is invalid")
            return
        }
        XCTAssertEqual(eventData.timestamp, 1)
        XCTAssertEqual(eventData.goalId, "goal_1")
        XCTAssertEqual(eventData.userId, "user_1")
        XCTAssertEqual(eventData.value, 2)
        XCTAssertEqual(eventData.user.id, "user_1")
        XCTAssertEqual(eventData.user.data["key_1"], "value_1")
        XCTAssertEqual(eventData.user.data["key_2"], "value_2")
        XCTAssertEqual(eventData.tag, "tag_1")
        XCTAssertEqual(eventData.sourceId, .ios)
    }

    func testDecodingEvaluationEvent() throws {
        let json = """
{
    "id": "event_1",
    "type": 3,
    "event": {
        "timestamp": 1,
        "featureId": "feature_1",
        "featureVersion": 2,
        "userId": "user_1",
        "variationId": "variation_1",
        "user": {
            "id": "user_1",
            "data": {
                "key_1": "value_1",
                "key_2": "value_2"
            }
        },
        "reason": {
            "type": "DEFAULT",
            "ruleId": "rule_1"
        },
        "tag": "tag_1",
        "sourceId": 2
    }
}
"""
        guard let data = json.data(using: .utf8) else {
            XCTFail("json is invalid")
            return
        }
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Event.self, from: data)
        XCTAssertEqual(decoded.id, "event_1")
        XCTAssertEqual(decoded.type, .evaluation)
        guard case .evaluation(let eventData) = decoded.event else {
            XCTFail("eventData is invalid")
            return
        }
        XCTAssertEqual(eventData.timestamp, 1)
        XCTAssertEqual(eventData.featureId, "feature_1")
        XCTAssertEqual(eventData.featureVersion, 2)
        XCTAssertEqual(eventData.userId, "user_1")
        XCTAssertEqual(eventData.variationId, "variation_1")
        XCTAssertEqual(eventData.user.id, "user_1")
        XCTAssertEqual(eventData.user.data["key_1"], "value_1")
        XCTAssertEqual(eventData.user.data["key_2"], "value_2")
        XCTAssertEqual(eventData.reason.type, .default)
        XCTAssertEqual(eventData.reason.ruleId, "rule_1")
        XCTAssertEqual(eventData.tag, "tag_1")
        XCTAssertEqual(eventData.sourceId, .ios)
    }

    func testDecodingMetricsResponseLatencyEvent() throws {
        let json = """
{
    "id": "event_1",
    "type": 4,
    "event": {
        "timestamp": 1,
        "type": 1,
        "sourceId": 2,
        "event": {
            "apiId": 2,
            "labels": {
                "key_1": "value_1",
                "key_2": "value_2",
            },
            "latencySecond": 1
        }
    }
}
"""
        guard let data = json.data(using: .utf8) else {
            XCTFail("json is invalid")
            return
        }
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Event.self, from: data)
        XCTAssertEqual(decoded.id, "event_1")
        XCTAssertEqual(decoded.type, .metrics)
        guard case .metrics(let eventData) = decoded.event else {
            XCTFail("eventData is invalid")
            return
        }
        XCTAssertEqual(eventData.timestamp, 1)
        XCTAssertEqual(eventData.type, .responseLatency)
        guard case .responseLatency(let metricsData) = eventData.event else {
            XCTFail("metricsData is invalid")
            return
        }
        XCTAssertEqual(metricsData.labels["key_1"], "value_1")
        XCTAssertEqual(metricsData.labels["key_2"], "value_2")
        XCTAssertEqual(metricsData.latencySecond, 1)
    }

    func testDecodingMetricsResponseSizeEvent() throws {
        let json = """
{
    "id": "event_1",
    "type": 4,
    "event": {
        "timestamp": 1,
        "type": 2,
        "sourceId": 2,
        "event": {
            "apiId": 2,
            "labels": {
                "key_1": "value_1",
                "key_2": "value_2",
            },
            "sizeByte": 1
        }
    }
}
"""
        guard let data = json.data(using: .utf8) else {
            XCTFail("json is invalid")
            return
        }
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Event.self, from: data)
        XCTAssertEqual(decoded.id, "event_1")
        XCTAssertEqual(decoded.type, .metrics)
        guard case .metrics(let eventData) = decoded.event else {
            XCTFail("eventData is invalid")
            return
        }
        XCTAssertEqual(eventData.timestamp, 1)
        XCTAssertEqual(eventData.type, .responseSize)
        guard case .responseSize(let metricsData) = eventData.event else {
            XCTFail("metricsData is invalid")
            return
        }
        XCTAssertEqual(metricsData.labels["key_1"], "value_1")
        XCTAssertEqual(metricsData.labels["key_2"], "value_2")
        XCTAssertEqual(metricsData.sizeByte, 1)
    }

    func testDecodingMetricsTimeoutErrorEvent() throws {
        let json = """
{
    "id": "event_1",
    "type": 4,
    "event": {
        "timestamp": 1,
        "type": 3,
        "sourceId": 2,
        "event": {
            "apiId": 2,
            "labels": {
                "tag": "tag_1"
            }
        }
    }
}
"""
        guard let data = json.data(using: .utf8) else {
            XCTFail("json is invalid")
            return
        }
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Event.self, from: data)
        XCTAssertEqual(decoded.id, "event_1")
        XCTAssertEqual(decoded.type, .metrics)
        guard case .metrics(let eventData) = decoded.event else {
            XCTFail("eventData is invalid")
            return
        }
        XCTAssertEqual(eventData.timestamp, 1)
        XCTAssertEqual(eventData.type, .timeoutError)
        guard case .timeoutError(let metricsData) = eventData.event else {
            XCTFail("metricsData is invalid")
            return
        }
        XCTAssertEqual(metricsData.labels, ["tag": "tag_1"])
    }

    func testDecodingMetricsInternalErrorEvent() throws {
        let json = """
{
    "id": "event_1",
    "type": 4,
    "event": {
        "timestamp": 1,
        "type": 5,
        "sourceId": 2,
        "event": {
            "apiId": 2,
            "labels": {
                "tag": "tag_1"
            }
        }
    }
}
"""
        guard let data = json.data(using: .utf8) else {
            XCTFail("json is invalid")
            return
        }
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Event.self, from: data)
        XCTAssertEqual(decoded.id, "event_1")
        XCTAssertEqual(decoded.type, .metrics)
        guard case .metrics(let eventData) = decoded.event else {
            XCTFail("eventData is invalid")
            return
        }
        XCTAssertEqual(eventData.timestamp, 1)
        XCTAssertEqual(eventData.type, .internalError)
        guard case .internalSdkError(let metricsData) = eventData.event else {
            XCTFail("metricsData is invalid")
            return
        }
        XCTAssertEqual(metricsData.labels, ["tag": "tag_1"])
    }
}
