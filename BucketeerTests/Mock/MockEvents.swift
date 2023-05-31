import Foundation
@testable import Bucketeer

extension Event {
    static let mockGoal1 = Event(
        id: "goal_event1",
        event: .goal(.init(
            timestamp: 1,
            goalId: "goal1",
            userId: User.mock1.id,
            value: 1,
            user: .mock1,
            tag: "tag1",
            sourceId: .ios,
            sdkVersion: "0.0.1",
            metadata: [
                "app_version": "1.2.3",
                "os_version": "16.0",
                "device_model": "iPhone14,7",
                "device_type": "mobile"
            ]
        )),
        type: .goal
    )

    static let mockGoal2 = Event(
        id: "goal_event2",
        event: .goal(.init(
            timestamp: 1,
            goalId: "goal2",
            userId: User.mock1.id,
            value: 1,
            user: .mock1,
            tag: "tag2",
            sourceId: .ios,
            sdkVersion: "0.0.1",
            metadata: [
                "app_version": "1.2.3",
                "os_version": "16.0",
                "device_model": "iPhone14,7",
                "device_type": "mobile"
            ]
        )),
        type: .goal
    )

    static let mockEvaluation1 = Event(
        id: "evaluation_event1",
        event: .evaluation(.init(
            timestamp: 1,
            featureId: "feature1",
            featureVersion: 1,
            userId: User.mock1.id,
            variationId: "variation1",
            user: .mock1,
            reason: .init(type: .rule, ruleId: "rule1"),
            tag: "tag1",
            sourceId: .ios,
            sdkVersion: "0.0.1",
            metadata: [
                "app_version": "1.2.3",
                "os_version": "16.0",
                "device_model": "iPhone14,7",
                "device_type": "mobile"
            ]
        )),
        type: .evaluation
    )

    static let mockEvaluation2 = Event(
        id: "evaluation_event2",
        event: .evaluation(.init(
            timestamp: 1,
            featureId: "feature2",
            featureVersion: 1,
            userId: User.mock1.id,
            variationId: "variation2",
            user: .mock1,
            reason: .init(type: .rule, ruleId: "rule2"),
            tag: "tag2",
            sourceId: .ios,
            sdkVersion: "0.0.1",
            metadata: [
                "app_version": "1.2.3",
                "os_version": "16.0",
                "device_model": "iPhone14,7",
                "device_type": "mobile"
            ]
        )),
        type: .evaluation
    )

    static let mockMetrics1 = Event(
        id: "metrics_event1",
        event: .metrics(.init(
            timestamp: 1,
            event: .responseLatency(.init(
                apiId: .getEvaluations,
                labels: ["tag": "ios", "state": "full"],
                latencySecond: .init(2)
            )),
            type: .responseLatency,
            sourceId: .ios,
            sdk_version: "0.0.1",
            metadata: [
                "app_version": "1.2.3",
                "os_version": "16.0",
                "device_model": "iPhone14,7",
                "device_type": "mobile"
            ]
        )),
        type: .metrics
    )

    static let mockMetrics2 = Event(
        id: "metrics_event2",
        event: .metrics(.init(
            timestamp: 1,
            event: .internalServerError(.init(
                apiId: .registerEvents,
                labels: [:]
            )),
            type: .internalServerError,
            sourceId: .ios,
            sdk_version: "0.0.1",
            metadata: [
                "app_version": "1.2.3",
                "os_version": "16.0",
                "device_model": "iPhone14,7",
                "device_type": "mobile"
            ]
        )),
        type: .metrics
    )

    static let mockMetrics3 = Event(
        id: "metrics_event3",
        event: .metrics(.init(
            timestamp: 2,
            event: .internalServerError(.init(
                apiId: .registerEvents,
                labels: [:]
            )),
            type: .internalServerError,
            sourceId: .ios,
            sdk_version: "0.0.1",
            metadata: [
                "app_version": "1.2.3",
                "os_version": "16.0",
                "device_model": "iPhone14,7",
                "device_type": "mobile"
            ]
        )),
        type: .metrics
    )
}
