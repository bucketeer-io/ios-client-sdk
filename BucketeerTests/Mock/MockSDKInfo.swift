import Foundation
@testable import Bucketeer

extension SDKInfo {
    static func testSample() -> SDKInfo {
        // random sourceId and sdkVersion for testing
        let sourceIds: [SourceID] = [.unknown, .android, .ios, .flutter, .react, .openFeatureKotlin, .openFeatureSwift]
        let randomSourceId = sourceIds.randomElement() ?? .ios
        let randomSdkVersion = "test-\(Int.random(in: 1...100))"
        return SDKInfo(sourceId: randomSourceId, sdkVersion: randomSdkVersion)
    }
}
