import Foundation

enum ReasonType: String, Codable, Hashable {
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
}
