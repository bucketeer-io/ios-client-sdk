import Foundation

/// Payload of the SSE `put` (full snapshot) and `patch` (delta) events. Which one it is
/// comes from the SSE `event:` field, not from this payload; the shape is identical.
///
/// Decoding is intentionally lenient on everything except `userEvaluationsId` and
/// `evaluations.createdAt`, mirroring the tolerance `GetEvaluationsResponse` already has
/// for the REST path: a protojson marshaler that omits zero-valued fields (a boolean
/// `false`, an empty array) sends no key at all for them, and this must not silently drop
/// every such patch. `evaluations.createdAt` stays required and must parse as a number: it
/// becomes `evaluatedAt` in storage, where a later PR's staleness guard compares it
/// numerically. An unreadable value there would silently disable that guard for every
/// subsequent write to this user's cache, so a malformed/missing `createdAt` is rejected
/// here instead of being allowed through with a corrupt value.
struct StreamEvaluationsEvent {
    let userEvaluationsId: String
    let evaluations: UserEvaluations

    /// Maps to the shape the polling path already writes to storage, so both paths can
    /// share one write function.
    func toGetEvaluationsResponse() -> GetEvaluationsResponse {
        GetEvaluationsResponse(evaluations: evaluations, userEvaluationsId: userEvaluationsId)
    }
}

extension StreamEvaluationsEvent: Decodable {
    private enum CodingKeys: String, CodingKey {
        case userEvaluationsId
        case evaluations
    }

    private enum EvaluationsCodingKeys: String, CodingKey {
        case id
        case evaluations
        case createdAt
        case forceUpdate
        case archivedFeatureIds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.userEvaluationsId = try container.decode(String.self, forKey: .userEvaluationsId)

        let evaluationsContainer = try container.nestedContainer(
            keyedBy: EvaluationsCodingKeys.self,
            forKey: .evaluations
        )

        let createdAt = try evaluationsContainer.decode(String.self, forKey: .createdAt)
        guard Int64(createdAt) != nil else {
            throw DecodingError.dataCorruptedError(
                forKey: .createdAt,
                in: evaluationsContainer,
                debugDescription: "createdAt must be a numeric string, got \"\(createdAt)\""
            )
        }

        let id = try evaluationsContainer.decodeIfPresent(String.self, forKey: .id) ?? ""
        let evaluationList = try evaluationsContainer.decodeIfPresent([Evaluation].self, forKey: .evaluations) ?? []
        let forceUpdate = try evaluationsContainer.decodeIfPresent(Bool.self, forKey: .forceUpdate) ?? false
        let archivedFeatureIds = try evaluationsContainer
            .decodeIfPresent([String].self, forKey: .archivedFeatureIds) ?? []

        self.evaluations = UserEvaluations(
            id: id,
            evaluations: evaluationList,
            createdAt: createdAt,
            forceUpdate: forceUpdate,
            archivedFeatureIds: archivedFeatureIds
        )
    }
}

/// Payload of the SSE `error` event, sent by the server immediately before it closes the
/// stream. Used only for logging, so every field is optional: a decode failure here must
/// never prevent the caller from handling the underlying connection error.
struct StreamErrorEvent: Decodable {
    let code: String?
    let message: String?
}
