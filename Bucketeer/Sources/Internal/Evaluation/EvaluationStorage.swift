import Foundation

protocol EvaluationStorage {
    func getBy(featureId: String) -> Evaluation?
    func get() throws -> [Evaluation]
    // force update
    func deleteAllAndInsert(
        evaluationId: String,
        evaluations: [Evaluation],
        evaluatedAt: String) throws
    // upsert
    @discardableResult func update(
        evaluationId: String,
        evaluations: [Evaluation],
        archivedFeatureIds: [String],
        evaluatedAt: String) throws -> Bool
    func refreshCache() throws

    var currentEvaluationsId: String { get }
    var featureTag: String { get }
    // expected set evaluatedAt from `deleteAllAndInsert` or `update` only
    var evaluatedAt: String { get }
    var userAttributesUpdated: Bool { get }

    // Current version and flag set when `setUserAttributesUpdated()` is called
    var userAttributesState: UserAttributesState { get }

    func clearCurrentEvaluationsId()
    func setFeatureTag(value: String)
    func setUserAttributesUpdated()
    func clearUserAttributesUpdated(version: Int)
}

/// Snapshot representing the current user-attributes update state.
///
/// - `version`: Monotonically increasing counter. Incremented each time `setUserAttributesUpdated()`
///   is called to indicate a new update event.
/// - `isUpdated`: `true` if user attributes have been modified since the last evaluation (i.e., a
///   new update event exists); `false` otherwise.
///
/// Use this struct to persist or return the minimal state needed to determine whether evaluations
/// must be refreshed due to user attribute changes.
struct UserAttributesState {
    let version: Int
    let isUpdated: Bool
}
