import Foundation
@testable import Bucketeer

struct MockSession: Session {
    var configuration: URLSessionConfiguration = .default
    var requestHandler: ((URLRequest) -> Void)?
    var data: Data?
    var response: HTTPURLResponse?
    var error: Error?

    func task(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        requestHandler?(request)
        completionHandler(data, response, error)
    }
}
