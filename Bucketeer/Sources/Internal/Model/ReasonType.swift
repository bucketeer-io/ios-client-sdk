import Foundation

enum ReasonType: String, Codable, Hashable {
    /// Successful evaluations:
    /// Evaluated using individual targeting.
    case target = "TARGET"
    /// Evaluated using a custom rule.
    case rule = "RULE"
    /// Evaluated using the default strategy.
    case `default` = "DEFAULT"
    /// Evaluated using the off variation.
    case offVariation = "OFF_VARIATION"
    /// Evaluated using a prerequisite.
    case prerequisite = "PREREQUISITE"
    /// Legacy client-side reason type. Previously used when the flag was missing in the cache
    /// and the default value was returned. Deprecated in favor of `errorFlagNotFound`.
    @available(*, deprecated, message: "ReasonType `client` has been deprecated. Use `error` prefixed reason types instead.")
    case client = "CLIENT"
    /// Error evaluations:
    /// No evaluations were performed.
    case errorNoEvaluations = "ERROR_NO_EVALUATIONS"
    /// The specified feature flag was not found.
    case errorFlagNotFound = "ERROR_FLAG_NOT_FOUND"
    /// The variation type does not match the expected type.
    case errorWrongType = "ERROR_WRONG_TYPE"
    /// User ID was not specified in the evaluation request.
    case errorUserIdNotSpecified = "ERROR_USER_ID_NOT_SPECIFIED"
    /// Feature flag ID was not specified in the evaluation request.
    case errorFeatureFlagIdNotSpecified = "ERROR_FEATURE_FLAG_ID_NOT_SPECIFIED"
    /// An unexpected error occurred during evaluation.
    case errorException = "ERROR_EXCEPTION"
    /// The cache is not ready after SDK initialization.
    case errorCacheNotFound = "ERROR_CACHE_NOT_FOUND"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        // If the raw value does not match any case, default to `.default`
        self = ReasonType(rawValue: rawValue) ?? .default
    }
}
