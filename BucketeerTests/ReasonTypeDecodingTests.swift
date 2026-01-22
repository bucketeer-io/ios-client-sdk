import XCTest
@testable import Bucketeer

class ReasonTypeDecodingTests: XCTestCase {
    func testDecodeValidAndInvalidReasonType() throws {
        let json = """
        [
            "TARGET",
            "RULE",
            "OFF_VARIATION",
            "PREREQUISITE",
            "INVALID_VALUE",
            "ERROR_NO_EVALUATIONS",
            "ERROR_FLAG_NOT_FOUND",
            "ERROR_WRONG_TYPE",
            "ERROR_USER_ID_NOT_SPECIFIED",
            "ERROR_FEATURE_FLAG_ID_NOT_SPECIFIED",
            "ERROR_EXCEPTION",
            "ERROR_CACHE_NOT_FOUND"
        ]
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let decoded = try decoder.decode([ReasonType].self, from: json)

        XCTAssertEqual(decoded, [
            .target,
            .rule,
            .offVariation,
            .prerequisite,
            // "INVALID_VALUE" should default to .default
            .default,
            .errorNoEvaluations,
            .errorFlagNotFound,
            .errorWrongType,
            .errorUserIdNotSpecified,
            .errorFeatureFlagIdNotSpecified,
            .errorException,
            .errorCacheNotFound
        ])
    }
}
