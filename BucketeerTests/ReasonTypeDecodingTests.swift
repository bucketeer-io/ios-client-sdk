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
            "INVALID_VALUE"
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
            .default
        ])
    }
}
