import XCTest
@testable import Bucketeer

/// `StreamingTask`: the request it sends and how it handles stream events.
/// Ported from the JS `test/internal/streaming/StreamingTask.spec.ts`.
///
/// Not ported, on purpose:
/// - "without config.eventSource the built-in FetchEventSource is used" and "config.eventSource
///   injected: the injected constructor is used": iOS has no injectable event source in the
///   config (URLSession works on every Apple platform). The factory is an internal init
///   parameter, which every test here uses.
/// - "applyEvaluationsResponse rejecting does not surface as an unhandled rejection": a JS
///   promise concern. `applyStreamedEvaluations` does not throw.
/// - "a synchronously throwing eventSource constructor starts the polling fallback": the
///   factory can't throw on iOS. A request build that throws is reported as a non-terminal
///   error (`StreamConnectionTests`), and a non-terminal error starts the fallback
///   (`StreamingTaskFallbackTests`).
final class StreamingTaskTests: XCTestCase {
    private var h: StreamingTaskHarness!

    override func setUp() {
        super.setUp()
        h = StreamingTaskHarness()
    }

    override func tearDown() {
        h.stop()
        h = nil
        super.tearDown()
    }

    // MARK: - Request

    func testRequestIsAPostToStreamEvaluationsWithTheFullHeadersAndBody() throws {
        h.startEnabled()

        XCTAssertEqual(h.sources.count, 1)
        let request = try XCTUnwrap(h.latest?.openedRequest)
        XCTAssertEqual(request.url?.absoluteString, "https://test.bucketeer.io/v1/gateway/stream_evaluations")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.allHTTPHeaderFields, [
            "Authorization": "api_key_value",
            "Content-Type": "application/json",
            "Accept": "text/event-stream"
        ])
        let expected: [String: Any] = [
            "tag": "feature_tag_value",
            "user": ["id": "user1", "data": ["age": "28"]],
            "sourceId": SourceID.ios.rawValue,
            "sdkVersion": "0.0.2",
            // Nothing cached yet: the "" / "0" defaults.
            "userEvaluationsId": "",
            "evaluatedAt": "0"
        ]
        XCTAssertEqual(try h.latestBody() as NSDictionary, expected as NSDictionary)
    }

    func testRequestSendsTheStoredUserEvaluationsIdAndEvaluatedAt() throws {
        h.setCachedEvaluationsState(.init(userEvaluationsId: "stored_evaluations_id", evaluatedAt: "1700000000"))
        h.startEnabled()

        let body = try h.latestBody()
        XCTAssertEqual(body["userEvaluationsId"] as? String, "stored_evaluations_id")
        XCTAssertEqual(body["evaluatedAt"] as? String, "1700000000")
    }

    // MARK: - Events

    func testPutEventIsApplied() {
        h.startEnabled()
        h.openLatest()

        h.emitOnLatest("put", StreamingTaskPayloads.valid())

        XCTAssertEqual(h.applied.count, 1)
        XCTAssertEqual(h.applied.first?.userEvaluationsId, "user_evaluation_id_value")
        XCTAssertEqual(h.applied.first?.evaluations, .mock1)
    }

    func testPatchEventIsApplied() {
        h.startEnabled()
        h.openLatest()

        h.emitOnLatest("patch", StreamingTaskPayloads.valid())

        XCTAssertEqual(h.applied.count, 1)
        XCTAssertEqual(h.applied.first?.evaluations, .mock1)
    }

    func testErrorEventIsLoggedAndNeverApplied() {
        h.startEnabled()
        h.openLatest()

        h.emitOnLatest("error", #"{"code":"INTERNAL","message":"evaluation failed"}"#)
        // A payload that doesn't decode as StreamErrorEvent is still logged, as raw data.
        h.emitOnLatest("error", #"{"code":13,"message":"internal"}"#)

        XCTAssertTrue(h.applied.isEmpty)
        let warnings = h.warnings
        XCTAssertEqual(warnings.count, 2)
        guard warnings.count == 2 else { return }
        XCTAssertTrue(warnings[0].contains("INTERNAL") && warnings[0].contains("evaluation failed"), warnings[0])
        XCTAssertTrue(warnings[1].contains(#"{"code":13,"message":"internal"}"#), warnings[1])
    }

    func testUnnamedMessageIsAppliedThroughOnUnhandledMessage() {
        h.startEnabled()
        h.openLatest()

        h.messageOnLatest(StreamingTaskPayloads.valid())

        XCTAssertEqual(h.applied.count, 1)
        XCTAssertEqual(h.applied.first?.evaluations, .mock1)
    }

    // Changed for iOS: JS applies this payload with forceUpdate = false. iOS decodes strictly
    // because the backend always sends zero values (EmitUnpopulated: true, see StreamErrorEvent).
    func testPayloadMissingForceUpdateIsDropped() {
        h.startEnabled()
        h.openLatest()
        let withoutForceUpdate = #"""
        {"evaluations":{"id":"evaluations_id","evaluations":[],"archivedFeatureIds":[],"createdAt":"1700000000"},"userEvaluationsId":"x"}
        """#
        let withForceUpdate = #"""
        {"evaluations":{"id":"evaluations_id","evaluations":[],"archivedFeatureIds":[],"createdAt":"1700000000","forceUpdate":false},"userEvaluationsId":"y"}
        """#

        h.emitOnLatest("patch", withoutForceUpdate)
        // Control: the same payload with the key present is applied, so the drop above is
        // because of forceUpdate, not some other field.
        h.emitOnLatest("patch", withForceUpdate)

        XCTAssertEqual(h.applied.map { $0.userEvaluationsId }, ["y"])
    }

    func testInvalidJsonIsIgnored() {
        h.startEnabled()
        h.openLatest()

        h.messageOnLatest("not-json")
        XCTAssertTrue(h.applied.isEmpty)

        // Control: the same channel applies a valid payload.
        h.messageOnLatest(StreamingTaskPayloads.valid())
        XCTAssertEqual(h.applied.count, 1)
    }

    func testValidJsonWithTheWrongShapeIsIgnored() {
        h.startEnabled()
        h.openLatest()

        for badPayload in [
            "{}",
            #"{"userEvaluationsId":"x"}"#, // missing evaluations
            #"{"userEvaluationsId":42,"evaluations":{"forceUpdate":false}}"#, // wrong type
            #"{"userEvaluationsId":"x","evaluations":null}"#, // evaluations not an object
            #"{"userEvaluationsId":"x","evaluations":{"forceUpdate":false}}"#, // missing createdAt
            #"{"userEvaluationsId":"x","evaluations":{"createdAt":1700000000,"forceUpdate":false}}"#, // createdAt not a string
            "[]",
            "null"
        ] {
            h.messageOnLatest(badPayload)
        }
        XCTAssertTrue(h.applied.isEmpty)

        // Control: the same channel applies a valid payload.
        h.messageOnLatest(StreamingTaskPayloads.valid())
        XCTAssertEqual(h.applied.count, 1)
    }

    // createdAt becomes evaluatedAt in storage, which the staleness guard compares. A payload
    // without it must never reach storage.
    func testPayloadMissingCreatedAtIsDropped() {
        h.startEnabled()
        h.openLatest()
        let payload = #"""
        {"evaluations":{"id":"evaluations_id","evaluations":[],"archivedFeatureIds":[],"forceUpdate":false},"userEvaluationsId":"x"}
        """#

        h.emitOnLatest("patch", payload)
        XCTAssertTrue(h.applied.isEmpty)

        // Control: the same event name applies a valid payload.
        h.emitOnLatest("patch", StreamingTaskPayloads.valid())
        XCTAssertEqual(h.applied.count, 1)
    }

    // On iOS, stop() closes the connection on the queue, after which the connection drops every
    // callback on its own. So the case that matters is data already waiting in the queue when
    // stop() is called: it runs before stop()'s queue block, against the still-open connection.
    // The task must drop it, because stop() marks the task stopped right away.
    func testDataQueuedBeforeStopIsNotApplied() {
        h.startEnabled()
        h.openLatest()
        // Control: data while running is applied.
        h.emitOnLatest("put", StreamingTaskPayloads.valid())
        XCTAssertEqual(h.applied.count, 1)
        let blocker = h.blockQueue()
        h.enqueueOnLatest { $0.emit("put", StreamingTaskPayloads.valid()) }

        h.task.stop()
        blocker.signal()
        h.drain()

        XCTAssertEqual(h.applied.count, 1)
    }

    func testShouldNotifyFlipsFalseRightAfterStop() throws {
        h.startEnabled()
        h.openLatest()
        h.emitOnLatest("put", StreamingTaskPayloads.valid())
        let shouldNotify = try XCTUnwrap(h.shouldNotifyHandlers.first)

        XCTAssertTrue(shouldNotify())
        h.task.stop() // no drain: the flag must flip before the queue runs anything
        XCTAssertFalse(shouldNotify())
    }
}
