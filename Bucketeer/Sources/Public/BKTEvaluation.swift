import Foundation

@available(*, deprecated, message: "Use BKTEvaluationDetails<T> instead")
public struct BKTEvaluation: Equatable {
    public let id: String
    public let featureId: String
    public let featureVersion: Int
    public let userId: String
    public let variationId: String
    public let variationName: String
    public let variationValue: String
    public let reason: Reason

    @available(*, deprecated, message: "Use BKTEvaluationDetails<T>.Reason instead")
    public enum Reason: String, Codable, Hashable {
        case target = "TARGET"
        case rule = "RULE"
        case `default` = "DEFAULT"
        case client = "CLIENT"
        case offVariation = "OFF_VARIATION"
        case prerequisite = "PREREQUISITE"
    }
}
