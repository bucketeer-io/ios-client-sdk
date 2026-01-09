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

/// Snapshot representing the current user-attributes update state for the current app session.
///
/// - `version`: Monotonically increasing counter. Incremented each time `setUserAttributesUpdated()`
///   is called to indicate a new update event. This value is kept in memory only and is not
///   persisted across app restarts.
/// - `isUpdated`: `true` if user attributes have been modified since the last evaluation (i.e., a
///   new update event exists); `false` otherwise. Implementations may persist this flag (for
///   example, in `UserDefaults`) to survive restarts.
///
/// Use this struct as an in-memory snapshot to coordinate whether evaluations must be refreshed
/// due to user attribute changes during a single session. It is not intended to be persisted as a
/// whole across app restarts.
struct UserAttributesState {
    let version: Int
    let isUpdated: Bool
}
