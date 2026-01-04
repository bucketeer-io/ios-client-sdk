protocol KeyValueCache {
    associatedtype DataCacheType
    func set(key: String, value: DataCacheType)
    func get(key: String) -> DataCacheType?
}

class InMemoryCache<T: Any>: KeyValueCache {
    typealias DataCacheType = T

    private var dict: [String: T] = [:]
    // A concurrent queue allows multiple reads to execute in parallel
    private let queue = DispatchQueue(label: "io.bucketeer.InMemoryCache", attributes: .concurrent)

    func set(key: String, value: T) {
        // .barrier ensures this write waits for current reads to finish,
        // and blocks new reads until the write is done.
        queue.async(flags: .barrier) {
            self.dict[key] = value
        }
    }

    func get(key: String) -> T? {
        // .sync returns the value immediately.
        // Because the queue is concurrent, this does NOT block other readers.
        queue.sync {
            return dict[key]
        }
    }
}

final class EvaluationMemCacheDao: InMemoryCache<[Evaluation]> {}
