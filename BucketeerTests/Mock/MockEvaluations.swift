import Foundation
@testable import Bucketeer

extension Evaluation {

    /// id: evaluation1 - user: user1, value: string
    static let mock1 = Evaluation(
        id: "feature1:1:user1",
        featureId: "feature1",
        featureVersion: 1,
        userId: User.mock1.id,
        variationId: "variation1",
        variationName: "variation name1",
        variationValue: "variation_value1",
        reason: .init(
            type: .rule,
            ruleId: "rule1"
        )
    )

    static let mock1Updated = Evaluation(
        id: "feature1:2:user1",
        featureId: "feature1",
        featureVersion: 2,
        userId: User.mock1.id,
        variationId: "variation1",
        variationName: "variation name1",
        variationValue: "variation_value1_updated",
        reason: .init(
            type: .rule,
            ruleId: "rule1"
        )
    )

    /// id: evaluation2 - user: user1, value: int
    static let mock2 = Evaluation(
        id: "feature2:1:user1",
        featureId: "feature2",
        featureVersion: 1,
        userId: User.mock1.id,
        variationId: "variation2",
        variationName: "variation name2",
        variationValue: "2",
        reason: .init(
            type: .rule,
            ruleId: "rule2"
        )
    )

    /// id: evaluation3 - user: user2, value: double
    static let mock3 = Evaluation(
        id: "feature3:1:user2",
        featureId: "feature3",
        featureVersion: 1,
        userId: User.mock2.id,
        variationId: "variation3",
        variationName: "variation name3",
        variationValue: "3.1",
        reason: .init(
            type: .rule,
            ruleId: "rule3"
        )
    )

    /// id: evaluation4 - user: user2, value: bool
    static let mock4 = Evaluation(
        id: "feature4:1:user2",
        featureId: "feature4",
        featureVersion: 1,
        userId: User.mock2.id,
        variationId: "variation4",
        variationName: "variation name4",
        variationValue: "true",
        reason: .init(
            type: .rule,
            ruleId: "rule4"
        )
    )

    /// id: evaluation5 - user: user2, value: json
    static let mock5 = Evaluation(
        id: "feature5:1:user2",
        featureId: "feature5",
        featureVersion: 1,
        userId: User.mock2.id,
        variationId: "variation5",
        variationName: "variation name5",
        variationValue: "{ \"key\": \"value\" }",
        reason: .init(
            type: .rule,
            ruleId: "rule5"
        )
    )

    static let stringEvaluation = Evaluation(
        id: "stringEvaluation:1:user2",
        featureId: "stringEvaluation",
        featureVersion: 1,
        userId: User.mock1.id,
        variationId: "variation string",
        variationName: "variation name string",
        variationValue: "test variation value",
        reason: .init(
            type: .rule,
            ruleId: "rule3"
        )
    )

    static let intEvaluation = Evaluation(
        id: "intEvaluation:1:user2",
        featureId: "intEvaluation",
        featureVersion: 1,
        userId: User.mock1.id,
        variationId: "variation int",
        variationName: "variation name int",
        variationValue: "1",
        reason: .init(
            type: .rule,
            ruleId: "rule3"
        )
    )

    static let doubleEvaluation = Evaluation(
        id: "doubleEvaluation:1:user2",
        featureId: "doubleEvaluation",
        featureVersion: 1,
        userId: User.mock1.id,
        variationId: "variation double",
        variationName: "variation name double",
        variationValue: "12.2",
        reason: .init(
            type: .rule,
            ruleId: "rule3"
        )
    )

    static let boolEvaluation = Evaluation(
        id: "boolEvaluation:1:user2",
        featureId: "boolEvaluation",
        featureVersion: 1,
        userId: User.mock1.id,
        variationId: "variation bool",
        variationName: "variation name bool",
        variationValue: "true",
        reason: .init(
            type: .rule,
            ruleId: "rule3"
        )
    )

    static let jsonEvaluation = Evaluation(
        id: "jsonEvaluation:1:user2",
        featureId: "jsonEvaluation",
        featureVersion: 1,
        userId: User.mock1.id,
        variationId: "variation json",
        variationName: "variation name json",
        variationValue: """
{
  "value" : "body",
  "value1" : "body1"
}
""",
        reason: .init(
            type: .rule,
            ruleId: "rule3"
        )
    )

    static let jsonObjectEvaluation = Evaluation(
        id: "jsonObjectEvaluation:1:user2",
        featureId: "jsonObjectEvaluation",
        featureVersion: 1,
        userId: User.mock1.id,
        variationId: "variation json",
        variationName: "variation name json",
        variationValue: """
{
  "value" : "body",
  "value1" : "body1",
  "valueInt" : 1,
  "valueBool" : true,
  "valueDouble" : 1.2,
  "valueDictionary": {"key" : "value"},
  "valueList1": [{"key" : "value"},{"key" : 10}],
  "valueList2": [1,2.2,true]
}
""",
        reason: .init(
            type: .rule,
            ruleId: "rule3"
        )
    )

    static let jsonArrayEvaluation = Evaluation(
        id: "jsonArrayEvaluation:1:user2",
        featureId: "jsonArrayEvaluation",
        featureVersion: 1,
        userId: User.mock1.id,
        variationId: "variation json",
        variationName: "variation name json",
        variationValue: """
[
{
  "value" : "body",
  "value1" : "body1"
},
{
  "value2" : "body2",
  "value3" : "body3"
}
]
""",
        reason: .init(
            type: .rule,
            ruleId: "rule3"
        )
    )
}

extension UserEvaluations {
    static let mock1 = UserEvaluations(
        id: "user_evaluation1",
        evaluations: [.mock1, .mock2],
        createdAt: "1690798000",
        forceUpdate: false,
        archivedFeatureIds: []
    )

    static let mock1Upsert = UserEvaluations(
        id: "user_evaluation1",
        evaluations: [.mock1Updated, .mock2],
        createdAt: "1690798021",
        forceUpdate: false,
        archivedFeatureIds: []
    )

    static let mock1ForceUpdate = UserEvaluations(
        id: "user_evaluation1",
        evaluations: [.mock1, .mock2],
        createdAt: "1690798021",
        forceUpdate: true,
        archivedFeatureIds: []
    )

    static let mock1UpsertAndArchivedFeature = UserEvaluations(
        id: "user_evaluation1",
        evaluations: [.mock1],
        createdAt: "1690798021",
        forceUpdate: false,
        archivedFeatureIds: [Evaluation.mock2.featureId]
    )

    static let mock2 = UserEvaluations(
        id: "user_evaluation2",
        evaluations: [.mock3, .mock4, .mock5],
        createdAt: "",
        forceUpdate: false,
        archivedFeatureIds: []
    )

    static let mockUserEvaluationsDetails = UserEvaluations(
        id: "user_evaluation_details",
        evaluations: [.stringEvaluation, .intEvaluation, .boolEvaluation, .doubleEvaluation, .jsonEvaluation, .jsonObjectEvaluation, .jsonArrayEvaluation],
        createdAt: "",
        forceUpdate: false,
        archivedFeatureIds: []
    )
}
