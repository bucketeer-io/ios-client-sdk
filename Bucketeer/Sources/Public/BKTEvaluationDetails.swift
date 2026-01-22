import Foundation

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
        @available(*, deprecated, message: "ReasonType `client` has been deprecated")
        case client = "CLIENT"

        case offVariation = "OFF_VARIATION"
        case prerequisite = "PREREQUISITE"

        case errorNoEvaluations = "ERROR_NO_EVALUATIONS"
        case errorFlagNotFound = "ERROR_FLAG_NOT_FOUND"
        case errorWrongType = "ERROR_WRONG_TYPE"
        case errorUserIdNotSpecified = "ERROR_USER_ID_NOT_SPECIFIED"
        case errorFeatureFlagIdNotSpecified = "ERROR_FEATURE_FLAG_ID_NOT_SPECIFIED"
        case errorException = "ERROR_EXCEPTION"

        public static func fromString(value: String) -> Reason {
            return Reason(rawValue: value) ?? .errorException
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

    static func newDefaultInstance(
        featureId: String,
        userId: String,
        defaultValue: T,
        reason: Reason
    ) -> BKTEvaluationDetails<T> {
        return BKTEvaluationDetails(
            featureId: featureId,
            featureVersion: 0,
            userId: userId,
            variationId: "",
            variationName: "",
            variationValue: defaultValue,
            reason: reason
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
