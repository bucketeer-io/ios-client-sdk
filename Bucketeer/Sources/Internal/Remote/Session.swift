import Foundation

protocol Session {
    var configuration: URLSessionConfiguration { get }

    func task(with request: URLRequest, completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void)
}

extension URLSession: Session {
    func task(with request: URLRequest, completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) {
        let task = dataTask(with: request, completionHandler: completionHandler)
        task.resume()
    }
}
