import Foundation

// EvaluationSQLDao CURD
protocol EvaluationSQLDao {
    func put(evaluations: [Evaluation]) throws
    func get(userId: String) throws -> [Evaluation]
    func deleteAll(userId: String) throws
    func deleteByIds(_ ids: [String]) throws
    func startTransaction(block: TransactionBlock) throws
}

typealias TransactionBlock = () throws -> Void
