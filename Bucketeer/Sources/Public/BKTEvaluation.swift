import Foundation

public struct BKTEvaluation: Equatable {
    public let id: String
    public let featureId: String
    public let featureVersion: Int
    public let userId: String
    public let variationId: String
    public let variationValue: String
    public let reason: Reason

    public typealias Reason = ReasonType
}
