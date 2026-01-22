import Foundation
@testable import Bucketeer

class MockSessionCounter {
    private let syncQueue = DispatchQueue(label: "io.bucketeer.MockSessionCounter.sync")
    private var _count: Int = 0

    var count: Int {
        return syncQueue.sync { _count }
    }

    fileprivate func increment() {
        syncQueue.sync { self._count += 1 }
    }
}

struct MockSession: Session {
    var configuration: URLSessionConfiguration = .default
    var requestHandler: ((URLRequest) -> Void)?
    var data: Data?
    var response: HTTPURLResponse?
    var error: Error?
    let networkQueue = DispatchQueue(label: "io.bucketeer.concurrentQueue.network", attributes: .concurrent)
    var invalidateAndCancelHandler: (() -> Void)?
    var responseProvider: ((URLRequest, Int) -> MockResponseData)?
    var taskCounter: MockSessionCounter = MockSessionCounter()

    func requestCount() -> Int {
        return taskCounter.count
    }

    func task(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        networkQueue.async {
            taskCounter.increment()
            let requestCount = taskCounter.count
            requestHandler?(request)
            if let responseProvider = self.responseProvider {
                // Dynamic response
                let responseData = responseProvider(request, requestCount)
                completionHandler(responseData.data, responseData.response, responseData.error)
                return
            }
            // Fixed response
            completionHandler(data, response, error)
        }
    }

    func invalidateAndCancel() {
        invalidateAndCancelHandler?()
    }
}

struct MockResponseData {
    let data: Data?
    let response: HTTPURLResponse?
    let error: Error?
}
