protocol KeyValueCache {
    associatedtype DataCacheType
    func set(key: String, value: DataCacheType)
    func get(key: String) -> DataCacheType?
}

class InMemoryCache<T:Any> : KeyValueCache {
    typealias DataCacheType = T

    private var dict: [String : T] = [:]

    func set(key: String, value: T) {
        dict[key] = value
    }

    func get(key: String) -> T? {
        return dict[key]
    }
}

final class EvaluationMemCacheDao: InMemoryCache<[Evaluation]> {}
