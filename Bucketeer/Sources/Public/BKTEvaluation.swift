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

public struct BKTEvaluationDetails<T:Equatable>: Equatable {
    public let featureId: String
    public let featureVersion: Int
    public let userId: String
    public let variationId: String
    public let variationName: String
    public let variationValue: T
    public let reason: Reason

    public enum Reason: String, Codable, Hashable {
        case target = "TARGET"
        case rule = "RULE"
        case `default` = "DEFAULT"
        case client = "CLIENT"
        case offVariation = "OFF_VARIATION"
        case prerequisite = "PREREQUISITE"

        public static func fromString(value: String) -> Reason {
            return Reason(rawValue: value) ?? .client
        }
    }

    public static func == (lhs: BKTEvaluationDetails<T>, rhs: BKTEvaluationDetails<T>) -> Bool {
        return lhs.featureId == rhs.featureId &&
        lhs.featureVersion == rhs.featureVersion &&
        lhs.userId == rhs.userId &&
        lhs.variationId == rhs.variationId &&
        lhs.variationName == rhs.variationName &&
        lhs.reason == rhs.reason &&
        lhs.variationValue == rhs.variationValue
    }

    static func newDefaultInstance(featureId: String, userId: String, defaultValue: T) -> BKTEvaluationDetails<T> {
        return BKTEvaluationDetails(
            featureId: featureId,
            featureVersion: 0,
            userId: userId,
            variationId: "",
            variationName: "",
            variationValue: defaultValue,
            reason: .client
        )
    }

    public init(featureId: String,
                featureVersion: Int,
                userId: String,
                variationId: String,
                variationName: String,
                variationValue: T,
                reason: Reason) {
        self.featureId = featureId
        self.featureVersion = featureVersion
        self.userId = userId
        self.variationId = variationId
        self.variationName = variationName
        self.variationValue = variationValue
        self.reason = reason
    }
}
