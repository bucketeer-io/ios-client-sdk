import XCTest
@testable import Bucketeer

// swiftlint:disable type_body_length
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
        XCTAssertEqual(client.objectVariation(
                        featureId: unknowFeatureId,
                        defaultValue: .dictionary( ["k":.string("v")])),
                       .dictionary(["k":.string("v")])
        )
    }

    func testEvaluationDetailDefaultValue() {
        let dataModule = MockDataModule(
            userHolder: .init(user: .mock1)
        )
        let client = BKTClient(dataModule: dataModule, dispatchQueue: .global())
        let unknowFeatureId = "unknowFeatureId"
        let userId = User.mock1.id
        XCTAssertEqual(
            client.intVariationDetails(featureId: unknowFeatureId, defaultValue: 1),
            BKTEvaluationDetails.newDefaultInstance(featureId: unknowFeatureId, userId: userId, defaultValue: 1, reason: .errorFlagNotFound)
        )
        XCTAssertEqual(
            client.stringVariationDetails(featureId: unknowFeatureId, defaultValue: "2"),
            BKTEvaluationDetails.newDefaultInstance(featureId: unknowFeatureId, userId: userId, defaultValue: "2", reason: .errorFlagNotFound)
        )
        XCTAssertEqual(
            client.boolVariationDetails(featureId: unknowFeatureId, defaultValue: true),
            BKTEvaluationDetails.newDefaultInstance(featureId: unknowFeatureId, userId: userId, defaultValue: true, reason: .errorFlagNotFound)
        )
        XCTAssertEqual(
            client.doubleVariationDetails(featureId: unknowFeatureId, defaultValue: 1.2),
            BKTEvaluationDetails.newDefaultInstance(featureId: unknowFeatureId, userId: userId, defaultValue: 1.2, reason: .errorFlagNotFound)
        )
        XCTAssertEqual(
            client.objectVariationDetails(featureId: unknowFeatureId, defaultValue: .boolean(false)),
            BKTEvaluationDetails.newDefaultInstance(featureId: unknowFeatureId, userId: userId, defaultValue: .boolean(false), reason: .errorFlagNotFound)
        )
    }

    func testStringEvaluationDetail() {
        let client = BKTClient.default!

        let expectedEvaluation = Evaluation.stringEvaluation
        let expectedEvaluationValue = expectedEvaluation.getVariationValue(defaultValue: "2.0", logger: nil)
        XCTAssertEqual(expectedEvaluationValue, "test variation value")

        let featureId = expectedEvaluation.featureId

        let actualEvaluation = client.stringVariationDetails(featureId: featureId, defaultValue: "2.0")
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
            client.doubleVariationDetails(featureId: featureId, defaultValue: 2.1),
            BKTEvaluationDetails.newDefaultInstance(featureId: featureId, userId: expectedEvaluation.userId, defaultValue: 2.1, reason: .errorWrongType)
        )

        XCTAssertEqual(
            client.boolVariationDetails(featureId: featureId, defaultValue: true),
            BKTEvaluationDetails.newDefaultInstance(featureId: featureId, userId: expectedEvaluation.userId, defaultValue: true, reason: .errorWrongType)
        )

        XCTAssertEqual(
            client.intVariationDetails(featureId: featureId, defaultValue: 1),
            BKTEvaluationDetails.newDefaultInstance(featureId: featureId, userId: expectedEvaluation.userId, defaultValue: 1, reason: .errorWrongType)
        )

        XCTAssertEqual(
            client.objectVariationDetails(featureId: featureId, defaultValue: .string("default")),
            BKTEvaluationDetails(
                featureId: expectedEvaluation.featureId,
                featureVersion: expectedEvaluation.featureVersion,
                userId: expectedEvaluation.userId,
                variationId: expectedEvaluation.variationId,
                variationName: expectedEvaluation.variationName,
                variationValue: .string(expectedEvaluationValue),
                reason: BKTEvaluationDetails.Reason.fromString(value: expectedEvaluation.reason.type.rawValue)
            )
        )
    }

    func testIntEvaluationDetail() {
        let client = BKTClient.default!

        let expectedEvaluation = Evaluation.intEvaluation
        let expectedEvaluationValue = expectedEvaluation.getVariationValue(defaultValue: 0, logger: nil)
        XCTAssertEqual(expectedEvaluationValue, 1)

        let featureId = expectedEvaluation.featureId

        let actualEvaluation = client.intVariationDetails(featureId: featureId, defaultValue: 2)
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

        let actualStringEvaluation = client.stringVariationDetails(featureId: featureId, defaultValue: "2")
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
            client.doubleVariationDetails(featureId: featureId, defaultValue: 2.1),
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
            client.boolVariationDetails(featureId: featureId, defaultValue: true),
            BKTEvaluationDetails.newDefaultInstance(featureId: featureId, userId: expectedEvaluation.userId, defaultValue: true, reason: .errorWrongType)
        )
        XCTAssertEqual(
            client.objectVariationDetails(featureId: featureId, defaultValue: .string("default")),
            BKTEvaluationDetails(
                featureId: expectedEvaluation.featureId,
                featureVersion: expectedEvaluation.featureVersion,
                userId: expectedEvaluation.userId,
                variationId: expectedEvaluation.variationId,
                variationName: expectedEvaluation.variationName,
                variationValue: .number(1),
                reason: BKTEvaluationDetails.Reason.fromString(value: expectedEvaluation.reason.type.rawValue)
            )
        )
    }

    func testBoolEvaluationDetail() {
        let client = BKTClient.default!

        let expectedEvaluation = Evaluation.boolEvaluation
        let expectedEvaluationValue = expectedEvaluation.getVariationValue(defaultValue: false, logger: nil)
        XCTAssertEqual(expectedEvaluationValue, true)

        let featureId = expectedEvaluation.featureId

        let actualEvaluation = client.boolVariationDetails(featureId: featureId, defaultValue: false)
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

        let actualStringEvaluation = client.stringVariationDetails(featureId: featureId, defaultValue: "2")
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
            client.doubleVariationDetails(featureId: featureId, defaultValue: 2.1),
            BKTEvaluationDetails.newDefaultInstance(featureId: featureId, userId: expectedEvaluation.userId, defaultValue: 2.1, reason: .errorWrongType)
        )

        XCTAssertEqual(
            client.intVariationDetails(featureId: featureId, defaultValue: 1),
            BKTEvaluationDetails.newDefaultInstance(featureId: featureId, userId: expectedEvaluation.userId, defaultValue: 1, reason: .errorWrongType)
        )
        XCTAssertEqual(
            client.objectVariationDetails(featureId: featureId, defaultValue: .string("default")),
            BKTEvaluationDetails(
                featureId: expectedEvaluation.featureId,
                featureVersion: expectedEvaluation.featureVersion,
                userId: expectedEvaluation.userId,
                variationId: expectedEvaluation.variationId,
                variationName: expectedEvaluation.variationName,
                variationValue: .boolean(true),
                reason: BKTEvaluationDetails.Reason.fromString(value: expectedEvaluation.reason.type.rawValue)
            )
        )
    }

    func testDoubleEvaluationDetail() {
        let client = BKTClient.default!

        let expectedEvaluation = Evaluation.doubleEvaluation
        let expectedEvaluationValue = expectedEvaluation.getVariationValue(defaultValue: 2.0, logger: nil)
        XCTAssertEqual(expectedEvaluationValue, 12.2)

        let featureId = expectedEvaluation.featureId

        let actualEvaluation = client.doubleVariationDetails(featureId: featureId, defaultValue: 2.0)
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

        let actualStringEvaluation = client.stringVariationDetails(featureId: featureId, defaultValue: "2.2")
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
            client.boolVariationDetails(featureId: featureId, defaultValue: true),
            BKTEvaluationDetails.newDefaultInstance(featureId: featureId, userId: expectedEvaluation.userId, defaultValue: true, reason: .errorWrongType)
        )

        XCTAssertEqual(
            client.intVariationDetails(featureId: featureId, defaultValue: 1),
            BKTEvaluationDetails(
                featureId: expectedEvaluation.featureId,
                featureVersion: expectedEvaluation.featureVersion,
                userId: expectedEvaluation.userId,
                variationId: expectedEvaluation.variationId,
                variationName: expectedEvaluation.variationName,
                variationValue: 12,
                reason: BKTEvaluationDetails.Reason.fromString(value: expectedEvaluation.reason.type.rawValue))
        )
        XCTAssertEqual(
            client.objectVariationDetails(featureId: featureId, defaultValue: .string("default")),
            BKTEvaluationDetails(
                featureId: expectedEvaluation.featureId,
                featureVersion: expectedEvaluation.featureVersion,
                userId: expectedEvaluation.userId,
                variationId: expectedEvaluation.variationId,
                variationName: expectedEvaluation.variationName,
                variationValue: .number(12.2),
                reason: BKTEvaluationDetails.Reason.fromString(value: expectedEvaluation.reason.type.rawValue)
            )
        )
    }

    func testObjectEvaluationDetailCaseDictionary() {
        let client = BKTClient.default!

        let expectedEvaluation = Evaluation.jsonObjectEvaluation
        let expectedEvaluationValue: BKTValue? = expectedEvaluation.getVariationValue(logger: nil)
        guard let expectedEvaluationValue = expectedEvaluationValue else {
            XCTFail("expectedEvaluationValue is nil")
            return
        }
        XCTAssertEqual(
            expectedEvaluationValue,
            .dictionary(
                [
                    "value": .string("body"),
                    "value1": .string("body1"),
                    "valueInt" : .number(1),
                    "valueBool" : .boolean(true),
                    "valueDouble" : .number(1.2),
                    "valueDictionary": .dictionary(["key" : .string("value")]),
                    "valueList1": .list(
                        [
                            .dictionary(["key" : .string("value")]),
                            .dictionary(["key" : .number(10)])
                        ]
                    ),
                    "valueList2": .list(
                        [
                            .number(1),
                            .number(2.2),
                            .boolean(true)
                        ]
                    )
                ]
            )
        )

        let featureId = expectedEvaluation.featureId

        let actualEvaluation = client.objectVariationDetails(featureId: featureId, defaultValue: .string("default"))
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
    }

    func testObjectEvaluationDetailCaseList() {
        let client = BKTClient.default!

        let expectedEvaluation = Evaluation.jsonArrayEvaluation
        let expectedEvaluationValue: BKTValue? = expectedEvaluation.getVariationValue(logger: nil)
        guard let expectedEvaluationValue = expectedEvaluationValue else {
            XCTFail("expectedEvaluationValue is nil")
            return
        }

        XCTAssertEqual(
            expectedEvaluationValue,
            .list(
                [
                    .dictionary(["value":.string("body"), "value1": .string("body1")]),
                    .dictionary(["value2":.string("body2"), "value3": .string("body3")])
                ]
            )
        )

        let featureId = expectedEvaluation.featureId

        let actualEvaluation = client.objectVariationDetails(featureId: featureId, defaultValue: .string("default"))
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
    }
}
// swiftlint:enable type_body_length
