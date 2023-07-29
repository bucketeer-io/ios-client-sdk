import Foundation

// EvaluationDao CURD
protocol EvaluationDao {
    func put(userId: String, evaluations: [Evaluation]) throws
    func get(userId: String) throws -> [Evaluation]
    func deleteAll(userId: String) throws
    func deleteByIds(_ ids: [String]) throws
    func startTransaction(block: TransactionBlock) throws
}

typealias TransactionBlock = () throws -> Void
