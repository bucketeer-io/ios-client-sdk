import Foundation

enum ReasonType: String, Codable, Hashable {
    case target = "TARGET"
    case rule = "RULE"
    case `default` = "DEFAULT"

    @available(*, deprecated, message: "ReasonType `client` has been deprecated")
    case client = "CLIENT"

    case offVariation = "OFF_VARIATION"
    case prerequisite = "PREREQUISITE"

    // Error Reasons for Client SDK
    case errorNoEvaluations = "ERROR_NO_EVALUATIONS"
    case errorWrongType = "ERROR_WRONG_TYPE"

    // Error Reasons for Server SDK can come from API response
    case errorFlagNotFound = "ERROR_FLAG_NOT_FOUND"
    case errorUserIdNotSpecified = "ERROR_USER_ID_NOT_SPECIFIED"
    case errorFeatureFlagIdNotSpecified = "ERROR_FEATURE_FLAG_ID_NOT_SPECIFIED"
    case errorException = "ERROR_EXCEPTION"
}
