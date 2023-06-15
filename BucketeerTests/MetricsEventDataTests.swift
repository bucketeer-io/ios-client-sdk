//
//  MetricsEventDataTests.swift
//  BucketeerTests
//
//  Created by Ryan Hung Pham on 15/06/2023.
//  Copyright © 2023 Bucketeer. All rights reserved.
//

import XCTest
@testable import Bucketeer

final class MetricsEventDataTests: XCTestCase {
    
    func testExample() throws {
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
            "registerEvents::type.googleapis.com/bucketeer.event.client.BadRequestErrorMetricsEvent",
        ]
        XCTAssertEqual(actual, expected)
    }
    
}
