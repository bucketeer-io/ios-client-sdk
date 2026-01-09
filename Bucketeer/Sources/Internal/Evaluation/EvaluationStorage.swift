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

    // Current version and flag set when `setUserAttributesUpdated()` is called
    var userAttributesState: UserAttributesState { get }

    func clearCurrentEvaluationsId()
    func setFeatureTag(value: String)
    func setUserAttributesUpdated()

    /// Atomically clear the user-attributes-updated flag if the stored version equals `state.version`.
    /// - Parameter state: Snapshot obtained from `userAttributesState` before a network request.
    /// - Returns: `true` if the flag was cleared (stored flag was `true` and versions matched); `false` otherwise.
    /// - Thread-safety: Implementations MUST perform the compare\-and\-swap under the storage's internal lock.
    /// - Note: `version` is an in\-memory, session-only counter; implementations may persist only the
    /// boolean flag (e.g., in `UserDefaults`), but the `version` must be treated as transient.
    @discardableResult func clearUserAttributesUpdated(state: UserAttributesState) -> Bool
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
