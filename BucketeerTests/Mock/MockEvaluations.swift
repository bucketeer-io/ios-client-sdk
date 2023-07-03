import Foundation
@testable import Bucketeer

extension Evaluation {

    /// id: evaluation1 - user: user1, value: string
    static let mock1 = Evaluation(
        id: "evaluation1",
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

    /// id: evaluation2 - user: user1, value: int
    static let mock2 = Evaluation(
        id: "evaluation2",
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
        id: "evaluation3",
        featureId: "feature3",
        featureVersion: 1,
        userId: User.mock2.id,
        variationId: "variation3",
        variationName: "variation name3",
        variationValue: "3.0",
        reason: .init(
            type: .rule,
            ruleId: "rule3"
        )
    )

    /// id: evaluation4 - user: user2, value: bool
    static let mock4 = Evaluation(
        id: "evaluation4",
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
        id: "evaluation5",
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
}

extension UserEvaluations {
    static let mock1 = UserEvaluations(
        id: "user_evaluation1",
        evaluations: [.mock1, .mock2]
    )

    static let mock2 = UserEvaluations(
        id: "user_evaluation2",
        evaluations: [.mock3, .mock4, .mock5]
    )
}
