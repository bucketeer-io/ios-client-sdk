import XCTest
@testable import Bucketeer

final class MetricsEventUniqueKeyTests: XCTestCase {

    func testMetricsEventDataPropsUniqueKey() throws {
        let target: [MetricsEventDataProps] = [
            MetricsEventData.ResponseLatency.init(
                apiId: .getEvaluations,
                labels: [:],
                latencySecond: .init(2)
            ),
            MetricsEventData.InternalSdkError.init(
                apiId: .registerEvents,
                labels: [:]
            ),
            MetricsEventData.ResponseSize.init(
                apiId: .getEvaluations,
                labels: [:],
                sizeByte: 748
            ),
            MetricsEventData.BadRequestError.init(
                apiId: .registerEvents,
                labels: [:]
            )
        ]

        let actual = target.map { item in
            item.uniqueKey()
        }
        let expected: [String] = [
            "getEvaluations::type.googleapis.com/bucketeer.event.client.LatencyMetricsEvent",
            "registerEvents::type.googleapis.com/bucketeer.event.client.InternalSdkErrorMetricsEvent",
            "getEvaluations::type.googleapis.com/bucketeer.event.client.SizeMetricsEvent",
            "registerEvents::type.googleapis.com/bucketeer.event.client.BadRequestErrorMetricsEvent"
        ]
        XCTAssertEqual(actual, expected)
    }

    func testMetricsEventUniqueKey() throws {
        let target: [Event] = [
            .mockMetricsResponseLatency1,
            .mockMetricsInternalServerError1,
            .mockMetricsResponseSize1,
            .mockMetricsBadRequest1,
            // mockGoal1 is not metric event , but we put here to check if there is some error
            .mockGoal1
        ]
        XCTAssertEqual(
            target.map { item in item.isMetricEvent() }, [true, true, true, true, false])
        let actual = target.map { item in
            item.uniqueKey()
        }
        let expected: [String] = [
            "getEvaluations::type.googleapis.com/bucketeer.event.client.LatencyMetricsEvent",
            "registerEvents::type.googleapis.com/bucketeer.event.client.InternalServerErrorMetricsEvent",
            "getEvaluations::type.googleapis.com/bucketeer.event.client.SizeMetricsEvent",
            "registerEvents::type.googleapis.com/bucketeer.event.client.BadRequestErrorMetricsEvent",
            // mockGoal1 is not metric event, uniqueKey will be its `id`
            "goal_event1"
        ]
        XCTAssertEqual(actual, expected)
    }
}
