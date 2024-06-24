import XCTest
@testable import Bucketeer

final class BKTClientEvaluationDetailTests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = 3
        expectation.assertForOverFulfill = true
        let dataModule = MockDataModule(
            userHolder: .init(user: .mock1),
            apiClient: MockApiClient(getEvaluationsHandler: { (user, _, _, _, handler) in
                expectation.fulfill()
                XCTAssertEqual(user, .mock1)
                handler?(.success(.init(evaluations: .mockUserEvaluationsDetails, userEvaluationsId: "new")))
            }),
            evaluationStorage: MockEvaluationStorage(
                userId: User.mock1.id,
                getHandler: {
                    XCTFail("should not reach here")
                    return []
                },
                updateHandler: { evaluations, archivedFeautureIds, evaluatedAt in
                    XCTAssertEqual(archivedFeautureIds, [])
                    XCTAssertEqual(evaluations, UserEvaluations.mockUserEvaluationsDetails.evaluations)
                    XCTAssertEqual(evaluatedAt, UserEvaluations.mockUserEvaluationsDetails.createdAt)
                    expectation.fulfill()
                    return true
                }, getByFeatureIdHandler: { featureId in
                    let evaluation = UserEvaluations.mockUserEvaluationsDetails.evaluations.first { evaluation in
                        return evaluation.featureId == featureId
                    }
                    return evaluation
                })
        )
        let client = BKTClient(dataModule: dataModule, dispatchQueue: .global())
        BKTClient.default = client
        client.fetchEvaluations(timeoutMillis: nil) { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    @MainActor
    override func tearDownWithError() throws {
        try BKTClient.destroy()
    }

    func testVariationDefaultValue() {
        let dataModule = MockDataModule(
            userHolder: .init(user: .mock1)
        )
        let client = BKTClient(dataModule: dataModule, dispatchQueue: .global())
        let unknowFeatureId = "unknowFeatureId"
        XCTAssertEqual(client.intVariation(featureId: unknowFeatureId, defaultValue: 1), 1)
        XCTAssertEqual(client.stringVariation(featureId: unknowFeatureId, defaultValue: "2"), "2")
        XCTAssertEqual(client.boolVariation(featureId: unknowFeatureId, defaultValue: true), true)
        XCTAssertEqual(client.doubleVariation(featureId: unknowFeatureId, defaultValue: 1.2), 1.2)
        XCTAssertEqual(client.jsonVariation(featureId: unknowFeatureId, defaultValue: ["k":"v"]), ["k":"v"])
    }

    func testEvaluationDetailDefaultValue() {
        let dataModule = MockDataModule(
            userHolder: .init(user: .mock1)
        )
        let client = BKTClient(dataModule: dataModule, dispatchQueue: .global())
        let unknowFeatureId = "unknowFeatureId"
        let userId = User.mock1.id
        XCTAssertEqual(
            client.intEvaluationDetails(featureId: unknowFeatureId, defaultValue: 1),
            BKTEvaluationDetails.newDefaultInstance(featureId: unknowFeatureId, userId: userId, defaultValue: 1)
        )
        XCTAssertEqual(
            client.stringEvaluationDetails(featureId: unknowFeatureId, defaultValue: "2"),
            BKTEvaluationDetails.newDefaultInstance(featureId: unknowFeatureId, userId: userId, defaultValue: "2")
        )
        XCTAssertEqual(
            client.boolEvaluationDetails(featureId: unknowFeatureId, defaultValue: true),
            BKTEvaluationDetails.newDefaultInstance(featureId: unknowFeatureId, userId: userId, defaultValue: true)
        )
        XCTAssertEqual(
            client.doubleEvaluationDetails(featureId: unknowFeatureId, defaultValue: 1.2),
            BKTEvaluationDetails.newDefaultInstance(featureId: unknowFeatureId, userId: userId, defaultValue: 1.2)
        )
        XCTAssertEqual(
            client.jsonEvaluationDetails(featureId: unknowFeatureId, defaultValue: ["k":"v", "v":"k"]),
            BKTEvaluationDetails.newDefaultInstance(featureId: unknowFeatureId, userId: userId, defaultValue: ["v":"k", "k":"v"])
        )
    }

    func testStringEvaluationDetail() {
        let client = BKTClient.default!

        let expectedEvaluation = Evaluation.stringEvaluation
        let expectedEvaluationValue = expectedEvaluation.getVariationValue(defaultValue: "2.0", logger: nil)
        XCTAssertEqual(expectedEvaluationValue, "test variation value")

        let featureId = expectedEvaluation.featureId

        let actualEvaluation = client.stringEvaluationDetails(featureId: featureId, defaultValue: "2.0")
        XCTAssertEqual(
            actualEvaluation,
            BKTEvaluationDetails(
                featureId: expectedEvaluation.featureId,
                featureVersion: expectedEvaluation.featureVersion,
                userId: expectedEvaluation.userId,
                variationId: expectedEvaluation.variationId,
                variationName: expectedEvaluation.variationName,
                variationValue: expectedEvaluationValue,
                reason: BKTEvaluationDetails.Reason.fromString(value: expectedEvaluation.reason.type.rawValue))
        )

        XCTAssertEqual(
            client.doubleEvaluationDetails(featureId: featureId, defaultValue: 2.1),
            BKTEvaluationDetails.newDefaultInstance(featureId: featureId, userId: expectedEvaluation.userId, defaultValue: 2.1)
        )

        XCTAssertEqual(
            client.boolEvaluationDetails(featureId: featureId, defaultValue: true),
            BKTEvaluationDetails.newDefaultInstance(featureId: featureId, userId: expectedEvaluation.userId, defaultValue: true)
        )

        XCTAssertEqual(
            client.intEvaluationDetails(featureId: featureId, defaultValue: 1),
            BKTEvaluationDetails.newDefaultInstance(featureId: featureId, userId: expectedEvaluation.userId, defaultValue: 1)
        )

        XCTAssertEqual(
            client.jsonEvaluationDetails(featureId: featureId, defaultValue: ["k":"v"]),
            BKTEvaluationDetails.newDefaultInstance(featureId: featureId, userId: expectedEvaluation.userId, defaultValue: ["k":"v"])
        )
    }

    func testIntEvaluationDetail() {
        let client = BKTClient.default!

        let expectedEvaluation = Evaluation.intEvaluation
        let expectedEvaluationValue = expectedEvaluation.getVariationValue(defaultValue: 0, logger: nil)
        XCTAssertEqual(expectedEvaluationValue, 1)

        let featureId = expectedEvaluation.featureId

        let actualEvaluation = client.intEvaluationDetails(featureId: featureId, defaultValue: 2)
        XCTAssertEqual(
            actualEvaluation,
            BKTEvaluationDetails(
                featureId: expectedEvaluation.featureId,
                featureVersion: expectedEvaluation.featureVersion,
                userId: expectedEvaluation.userId,
                variationId: expectedEvaluation.variationId,
                variationName: expectedEvaluation.variationName,
                variationValue: expectedEvaluationValue,
                reason: BKTEvaluationDetails.Reason.fromString(value: expectedEvaluation.reason.type.rawValue))
        )

        let actualStringEvaluation = client.stringEvaluationDetails(featureId: featureId, defaultValue: "2")
        XCTAssertEqual(
            actualStringEvaluation,
            BKTEvaluationDetails(
                featureId: expectedEvaluation.featureId,
                featureVersion: expectedEvaluation.featureVersion,
                userId: expectedEvaluation.userId,
                variationId: expectedEvaluation.variationId,
                variationName: expectedEvaluation.variationName,
                variationValue: "1",
                reason: BKTEvaluationDetails.Reason.fromString(value: expectedEvaluation.reason.type.rawValue))
        )

        XCTAssertEqual(
            client.doubleEvaluationDetails(featureId: featureId, defaultValue: 2.1),
            BKTEvaluationDetails(
                featureId: expectedEvaluation.featureId,
                featureVersion: expectedEvaluation.featureVersion,
                userId: expectedEvaluation.userId,
                variationId: expectedEvaluation.variationId,
                variationName: expectedEvaluation.variationName,
                variationValue: 1.0,
                reason: BKTEvaluationDetails.Reason.fromString(value: expectedEvaluation.reason.type.rawValue))
        )

        XCTAssertEqual(
            client.boolEvaluationDetails(featureId: featureId, defaultValue: true),
            BKTEvaluationDetails.newDefaultInstance(featureId: featureId, userId: expectedEvaluation.userId, defaultValue: true)
        )

        XCTAssertEqual(
            client.jsonEvaluationDetails(featureId: featureId, defaultValue: ["k":"v"]),
            BKTEvaluationDetails.newDefaultInstance(featureId: featureId, userId: expectedEvaluation.userId, defaultValue: ["k":"v"])
        )
    }

    func testBoolEvaluationDetail() {
        let client = BKTClient.default!

        let expectedEvaluation = Evaluation.boolEvaluation
        let expectedEvaluationValue = expectedEvaluation.getVariationValue(defaultValue: false, logger: nil)
        XCTAssertEqual(expectedEvaluationValue, true)

        let featureId = expectedEvaluation.featureId

        let actualEvaluation = client.boolEvaluationDetails(featureId: featureId, defaultValue: false)
        XCTAssertEqual(
            actualEvaluation,
            BKTEvaluationDetails(
                featureId: expectedEvaluation.featureId,
                featureVersion: expectedEvaluation.featureVersion,
                userId: expectedEvaluation.userId,
                variationId: expectedEvaluation.variationId,
                variationName: expectedEvaluation.variationName,
                variationValue: expectedEvaluationValue,
                reason: BKTEvaluationDetails.Reason.fromString(value: expectedEvaluation.reason.type.rawValue))
        )

        let actualStringEvaluation = client.stringEvaluationDetails(featureId: featureId, defaultValue: "2")
        XCTAssertEqual(
            actualStringEvaluation,
            BKTEvaluationDetails(
                featureId: expectedEvaluation.featureId,
                featureVersion: expectedEvaluation.featureVersion,
                userId: expectedEvaluation.userId,
                variationId: expectedEvaluation.variationId,
                variationName: expectedEvaluation.variationName,
                variationValue: "true",
                reason: BKTEvaluationDetails.Reason.fromString(value: expectedEvaluation.reason.type.rawValue))
        )

        XCTAssertEqual(
            client.doubleEvaluationDetails(featureId: featureId, defaultValue: 2.1),
            BKTEvaluationDetails.newDefaultInstance(featureId: featureId, userId: expectedEvaluation.userId, defaultValue: 2.1)
        )

        XCTAssertEqual(
            client.intEvaluationDetails(featureId: featureId, defaultValue: 1),
            BKTEvaluationDetails.newDefaultInstance(featureId: featureId, userId: expectedEvaluation.userId, defaultValue: 1)
        )

        XCTAssertEqual(
            client.jsonEvaluationDetails(featureId: featureId, defaultValue: ["k":"v"]),
            BKTEvaluationDetails.newDefaultInstance(featureId: featureId, userId: expectedEvaluation.userId, defaultValue: ["k":"v"])
        )
    }

    func testDoubleEvaluationDetail() {
        let client = BKTClient.default!

        let expectedEvaluation = Evaluation.doubleEvaluation
        let expectedEvaluationValue = expectedEvaluation.getVariationValue(defaultValue: 2.0, logger: nil)
        XCTAssertEqual(expectedEvaluationValue, 12.2)

        let featureId = expectedEvaluation.featureId

        let actualEvaluation = client.doubleEvaluationDetails(featureId: featureId, defaultValue: 2.0)
        XCTAssertEqual(
            actualEvaluation,
            BKTEvaluationDetails(
                featureId: expectedEvaluation.featureId,
                featureVersion: expectedEvaluation.featureVersion,
                userId: expectedEvaluation.userId,
                variationId: expectedEvaluation.variationId,
                variationName: expectedEvaluation.variationName,
                variationValue: expectedEvaluationValue,
                reason: BKTEvaluationDetails.Reason.fromString(value: expectedEvaluation.reason.type.rawValue))
        )

        let actualStringEvaluation = client.stringEvaluationDetails(featureId: featureId, defaultValue: "2.2")
        XCTAssertEqual(
            actualStringEvaluation,
            BKTEvaluationDetails(
                featureId: expectedEvaluation.featureId,
                featureVersion: expectedEvaluation.featureVersion,
                userId: expectedEvaluation.userId,
                variationId: expectedEvaluation.variationId,
                variationName: expectedEvaluation.variationName,
                variationValue: "12.2",
                reason: BKTEvaluationDetails.Reason.fromString(value: expectedEvaluation.reason.type.rawValue))
        )

        XCTAssertEqual(
            client.boolEvaluationDetails(featureId: featureId, defaultValue: true),
            BKTEvaluationDetails.newDefaultInstance(featureId: featureId, userId: expectedEvaluation.userId, defaultValue: true)
        )

        XCTAssertEqual(
            client.intEvaluationDetails(featureId: featureId, defaultValue: 1),
            BKTEvaluationDetails.newDefaultInstance(featureId: featureId, userId: expectedEvaluation.userId, defaultValue: 1)
        )

        XCTAssertEqual(
            client.jsonEvaluationDetails(featureId: featureId, defaultValue: ["k":"v"]),
            BKTEvaluationDetails.newDefaultInstance(featureId: featureId, userId: expectedEvaluation.userId, defaultValue: ["k":"v"])
        )
    }

    func testJsonEvaluationDetail() {
        let client = BKTClient.default!

        let expectedEvaluation = Evaluation.jsonEvaluation
        let expectedEvaluationValue: [String: AnyHashable] = expectedEvaluation.getVariationValue(defaultValue: ["k":"k"], logger: nil)

        XCTAssertEqual(expectedEvaluationValue, ["value":"body", "value1":"body1"])

        let featureId = expectedEvaluation.featureId

        XCTAssertEqual(
            client.jsonEvaluationDetails(featureId: featureId, defaultValue: ["k":"v"]),
            BKTEvaluationDetails(
                featureId: expectedEvaluation.featureId,
                featureVersion: expectedEvaluation.featureVersion,
                userId: expectedEvaluation.userId,
                variationId: expectedEvaluation.variationId,
                variationName: expectedEvaluation.variationName,
                variationValue: ["value":"body", "value1":"body1"],
                reason: BKTEvaluationDetails.Reason.fromString(value: expectedEvaluation.reason.type.rawValue))
        )

        XCTAssertEqual(
            client.doubleEvaluationDetails(featureId: featureId, defaultValue: 2.1),
            BKTEvaluationDetails.newDefaultInstance(featureId: featureId, userId: expectedEvaluation.userId, defaultValue: 2.1)
        )

        XCTAssertEqual(
            client.boolEvaluationDetails(featureId: featureId, defaultValue: true),
            BKTEvaluationDetails.newDefaultInstance(featureId: featureId, userId: expectedEvaluation.userId, defaultValue: true)
        )

        XCTAssertEqual(
            client.intEvaluationDetails(featureId: featureId, defaultValue: 1),
            BKTEvaluationDetails.newDefaultInstance(featureId: featureId, userId: expectedEvaluation.userId, defaultValue: 1)
        )

        XCTAssertEqual(
            client.stringEvaluationDetails(featureId: featureId, defaultValue: "2.0"),
            BKTEvaluationDetails(
                featureId: expectedEvaluation.featureId,
                featureVersion: expectedEvaluation.featureVersion,
                userId: expectedEvaluation.userId,
                variationId: expectedEvaluation.variationId,
                variationName: expectedEvaluation.variationName,
                variationValue: """
{
  "value" : "body",
  "value1" : "body1"
}
""",
                reason: BKTEvaluationDetails.Reason.fromString(value: expectedEvaluation.reason.type.rawValue))
        )
    }
}
