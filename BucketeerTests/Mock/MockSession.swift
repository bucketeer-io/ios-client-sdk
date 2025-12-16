import Foundation
@testable import Bucketeer

class MockSessionCounter {
    var count: Int = 0

    func increment() {
        count += 1
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

    func task(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        networkQueue.async {
            taskCounter.increment()
            requestHandler?(request)
            networkQueue.asyncAfter(deadline: .now() + 0.1) {
                if let responseProvider = self.responseProvider {
                    // Dynamic response
                    let responseData = responseProvider(request, taskCounter.count)
                    completionHandler(responseData.data, responseData.response, responseData.error)
                    return
                }
                // Fixed response
                completionHandler(data, response, error)
            }
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
