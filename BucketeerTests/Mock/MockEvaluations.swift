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
        variation: .init(
            id: "variation1",
            value: "value1",
            name: "name1",
            description: "description1"
        ),
        reason: .init(
            type: .rule,
            ruleId: "rule1"
        ),
        variationValue: "variation_value1"
    )

    /// id: evaluation2 - user: user1, value: int
    static let mock2 = Evaluation(
        id: "evaluation2",
        featureId: "feature2",
        featureVersion: 1,
        userId: User.mock1.id,
        variationId: "variation2",
        variation: .init(
            id: "variation2",
            value: "2",
            name: "name2",
            description: "description2"
        ),
        reason: .init(
            type: .rule,
            ruleId: "rule2"
        ),
        variationValue: "2"
    )

    /// id: evaluation3 - user: user2, value: double
    static let mock3 = Evaluation(
        id: "evaluation3",
        featureId: "feature3",
        featureVersion: 1,
        userId: User.mock2.id,
        variationId: "variation3",
        variation: .init(
            id: "variation3",
            value: "3.0",
            name: "name3",
            description: "description3"
        ),
        reason: .init(
            type: .rule,
            ruleId: "rule3"
        ),
        variationValue: "3.0"
    )

    /// id: evaluation4 - user: user2, value: bool
    static let mock4 = Evaluation(
        id: "evaluation4",
        featureId: "feature4",
        featureVersion: 1,
        userId: User.mock2.id,
        variationId: "variation4",
        variation: .init(
            id: "variation4",
            value: "true",
            name: "flag",
            description: "description4"
        ),
        reason: .init(
            type: .rule,
            ruleId: "rule4"
        ),
        variationValue: "true"
    )

    /// id: evaluation5 - user: user2, value: json
    static let mock5 = Evaluation(
        id: "evaluation5",
        featureId: "feature5",
        featureVersion: 1,
        userId: User.mock2.id,
        variationId: "variation5",
        variation: .init(
            id: "variation5",
            value: "{ \"key\": \"value\" }",
            name: "flag",
            description: "description4"
        ),
        reason: .init(
            type: .rule,
            ruleId: "rule5"
        ),
        variationValue: "{ \"key\": \"value\" }"
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
