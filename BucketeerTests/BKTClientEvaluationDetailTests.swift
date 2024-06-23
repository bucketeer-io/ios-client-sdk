import XCTest
@testable import Bucketeer

final class BKTClientEvaluationDetailTests: XCTestCase {

    override func setUp() {
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

    override func tearDown() async throws {
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
            BKTEvaluationDetail.newDefaultInstance(featureId: unknowFeatureId, userId: userId, defaultValue: 1)
        )
        XCTAssertEqual(
            client.stringEvaluationDetails(featureId: unknowFeatureId, defaultValue: "2"),
            BKTEvaluationDetail.newDefaultInstance(featureId: unknowFeatureId, userId: userId, defaultValue: "2")
        )
        XCTAssertEqual(
            client.boolEvaluationDetails(featureId: unknowFeatureId, defaultValue: true),
            BKTEvaluationDetail.newDefaultInstance(featureId: unknowFeatureId, userId: userId, defaultValue: true)
        )
        XCTAssertEqual(
            client.doubleEvaluationDetails(featureId: unknowFeatureId, defaultValue: 1.2),
            BKTEvaluationDetail.newDefaultInstance(featureId: unknowFeatureId, userId: userId, defaultValue: 1.2)
        )
        XCTAssertEqual(
            client.jsonEvaluationDetails(featureId: unknowFeatureId, defaultValue: ["k":"v", "v":"k"]),
            BKTEvaluationDetail.newDefaultInstance(featureId: unknowFeatureId, userId: userId, defaultValue: ["v":"k", "k":"v"])
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
            BKTEvaluationDetail(
                featureId: expectedEvaluation.featureId,
                featureVersion: expectedEvaluation.featureVersion,
                userId: expectedEvaluation.userId,
                variationId: expectedEvaluation.variationId,
                variationName: expectedEvaluation.variationName,
                variationValue: expectedEvaluationValue,
                reason: BKTEvaluationDetail.Reason.fromString(value: expectedEvaluation.reason.type.rawValue))
        )

        let actualStringEvaluation = client.stringEvaluationDetails(featureId: featureId, defaultValue: "2")
        XCTAssertEqual(
            actualStringEvaluation,
            BKTEvaluationDetail(
                featureId: expectedEvaluation.featureId,
                featureVersion: expectedEvaluation.featureVersion,
                userId: expectedEvaluation.userId,
                variationId: expectedEvaluation.variationId,
                variationName: expectedEvaluation.variationName,
                variationValue: expectedEvaluation.variationValue,
                reason: BKTEvaluationDetail.Reason.fromString(value: expectedEvaluation.reason.type.rawValue))
        )
    }
}
