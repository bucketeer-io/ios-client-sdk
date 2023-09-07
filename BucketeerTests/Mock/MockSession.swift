import Foundation
@testable import Bucketeer

struct MockSession: Session {
    var configuration: URLSessionConfiguration = .default
    var requestHandler: ((URLRequest) -> Void)?
    var data: Data?
    var response: HTTPURLResponse?
    var error: Error?
    let networkQueue = DispatchQueue(label: "io.bucketeer.concurrentQueue.network", attributes: .concurrent)
    var invalidateAndCancelHandler: (() -> Void)?

    func task(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        networkQueue.async {
            requestHandler?(request)
            networkQueue.asyncAfter(deadline: .now() + 0.1) {
                completionHandler(data, response, error)
            }
        }
    }
    
    func invalidateAndCancel() {
        invalidateAndCancelHandler?()
    }
}
