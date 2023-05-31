import Foundation

protocol EvaluationDao {
    func put(userId: String, evaluations: [Evaluation]) throws
    func get(userId: String) throws -> [Evaluation]
    func deleteAllAndInsert(userId: String, evaluations: [Evaluation]) throws
}
