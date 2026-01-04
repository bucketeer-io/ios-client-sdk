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
        // .barrier ensures exclusive access: it waits for pending reads to finish and blocks new ones during the write.
        // .sync ensures the update completes before returning, guaranteeing that subsequent reads immediately receive the new value.
        queue.sync(flags: .barrier) {
            self.dict[key] = value
        }
    }

    func get(key: String) -> T? {
        // .sync waits for this read block to run, then returns its value.
        // Reads can run in parallel on the concurrent queue, but this call will wait if a barrier write is in progress or queued ahead of it.
        queue.sync {
            return dict[key]
        }
    }
}

final class EvaluationMemCacheDao: InMemoryCache<[Evaluation]> {}
