import Foundation
import Network

/// A small HTTP proxy server for the streaming E2E tests. The SDK is pointed at `url` through
/// the public `apiEndpoint` setting, and the proxy forwards every request to the real backend,
/// passing each reply back as it arrives (a stream piece by piece) and recording each request's
/// path and reply status. The client under test starts exactly as an app starts it; only its
/// address changes. See `BucketeerTests/E2E/README.md` for why the tests work this way.
///
/// One request per connection: every reply carries `Connection: close` and ends by closing the
/// connection. Listener, connections and the forwarding session all run on one serial queue.
/// Call `stop()` when done: the forwarding session keeps the proxy alive until then.
final class E2ERecordingProxy: NSObject {
    struct Record: Equatable {
        let method: String
        let path: String
        var status: Int?
        var error: String?
    }

    /// The address to give the SDK: `http://127.0.0.1:<port>` plus the backend's path.
    private(set) var url: URL

    private let upstream: URL
    private let queue = DispatchQueue(label: "io.bucketeer.test.e2eRecordingProxy")
    private let listener: NWListener
    private var session: URLSession!
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private var exchanges: [Int: Exchange] = [:]
    private var isStopped = false

    private let recordsLock = NSLock()
    private var _records: [Record] = []

    /// Request headers that describe the client's hop to the proxy, set again by the forwarding
    /// session for the hop to the backend.
    private static let droppedRequestHeaders: Set<String> = [
        "host", "connection", "content-length", "transfer-encoding", "keep-alive", "accept-encoding"
    ]
    /// The forwarding session has already unzipped the body and reads it in full, so the
    /// backend's encoding and length no longer describe what the proxy sends.
    private static let droppedResponseHeaders: Set<String> = [
        "content-encoding", "content-length", "transfer-encoding", "connection", "keep-alive"
    ]

    private final class Exchange {
        let connection: NWConnection
        let task: URLSessionDataTask
        let recordIndex: Int

        init(connection: NWConnection, task: URLSessionDataTask, recordIndex: Int) {
            self.connection = connection
            self.task = task
            self.recordIndex = recordIndex
        }
    }

    /// - Parameters:
    ///   - upstream: The real backend endpoint (for example `E2E_API_ENDPOINT`).
    ///   - configuration: The forwarding session's settings. The proxy's own tests pass one
    ///     that routes to a scripted fake backend.
    init(upstream: URL, configuration: URLSessionConfiguration = .ephemeral) throws {
        self.upstream = upstream
        let parameters = NWParameters.tcp
        parameters.requiredInterfaceType = .loopback
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters)

        // Placeholder until the listener reports its port below.
        url = upstream
        super.init()

        let delegateQueue = OperationQueue()
        delegateQueue.underlyingQueue = queue
        delegateQueue.maxConcurrentOperationCount = 1
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)

        let ready = DispatchSemaphore(value: 0)
        var failure: Error?
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                ready.signal()
            case .failed(let error):
                failure = error
                ready.signal()
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.start(queue: queue)
        guard ready.wait(timeout: .now() + 5) == .success, failure == nil, let port = listener.port else {
            listener.cancel()
            session.invalidateAndCancel()
            throw failure ?? URLError(.cannotConnectToHost)
        }
        listener.stateUpdateHandler = nil

        var components = URLComponents()
        components.scheme = "http"
        components.host = "127.0.0.1"
        components.port = Int(port.rawValue)
        components.percentEncodedPath = URLComponents(url: upstream, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? ""
        guard let proxyURL = components.url else {
            throw URLError(.badURL)
        }
        url = proxyURL
    }

    /// Every request received so far, in order.
    var records: [Record] {
        recordsLock.withLock { _records }
    }

    /// How many requests had a path ending with `pathSuffix`.
    func count(of pathSuffix: String) -> Int {
        records.filter { $0.path.hasSuffix(pathSuffix) }.count
    }

    /// Cancels every backend request, closes every connection, stops listening and releases
    /// the forwarding session. Call it from the test, never from the proxy's queue.
    func stop() {
        queue.sync {
            guard !isStopped else { return }
            isStopped = true
            listener.cancel()
            exchanges.values.forEach { $0.task.cancel() }
            exchanges.removeAll()
            connections.values.forEach { $0.cancel() }
            connections.removeAll()
        }
        session.invalidateAndCancel()
    }

    // MARK: - Connections (all on `queue`)

    private func accept(_ connection: NWConnection) {
        guard !isStopped else {
            connection.cancel()
            return
        }
        connections[ObjectIdentifier(connection)] = connection
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                self?.connectionEnded(connection)
            default:
                break
            }
        }
        connection.start(queue: queue)
        readRequest(on: connection, buffer: Data())
    }

    private func readRequest(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }
            if let request = HTTPRequest(parsing: buffer) {
                self.forward(request, from: connection)
            } else if isComplete || error != nil {
                connection.cancel()
            } else {
                self.readRequest(on: connection, buffer: buffer)
            }
        }
    }

    private func forward(_ request: HTTPRequest, from connection: NWConnection) {
        let recordIndex = recordsLock.withLock { () -> Int in
            _records.append(Record(method: request.method, path: request.path, status: nil, error: nil))
            return _records.count - 1
        }

        var urlRequest = URLRequest(url: forwardingURL(for: request.target))
        urlRequest.httpMethod = request.method
        // Longer than the SDK's own silence limit for the stream, so the SDK decides when a
        // quiet stream is dead, not the proxy.
        urlRequest.timeoutInterval = 120
        for (name, value) in request.headers where !Self.droppedRequestHeaders.contains(name.lowercased()) {
            urlRequest.addValue(value, forHTTPHeaderField: name)
        }
        if !request.body.isEmpty {
            urlRequest.httpBody = request.body
        }

        let task = session.dataTask(with: urlRequest)
        exchanges[task.taskIdentifier] = Exchange(connection: connection, task: task, recordIndex: recordIndex)
        task.resume()
        watchForClientClose(on: connection, task: task)
    }

    /// The client sends nothing after its request, so any read that ends means it closed the
    /// connection (for example the SDK reconnecting its stream). Cancel the backend request.
    private func watchForClientClose(on connection: NWConnection, task: URLSessionDataTask) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if isComplete || error != nil {
                self.endExchange(taskIdentifier: task.taskIdentifier, cancelTask: true)
            } else if data != nil {
                self.watchForClientClose(on: connection, task: task)
            }
        }
    }

    private func connectionEnded(_ connection: NWConnection) {
        connections[ObjectIdentifier(connection)] = nil
        if let taskIdentifier = exchanges.first(where: { $0.value.connection === connection })?.key {
            endExchange(taskIdentifier: taskIdentifier, cancelTask: true)
        }
    }

    private func endExchange(taskIdentifier: Int, cancelTask: Bool) {
        guard let exchange = exchanges.removeValue(forKey: taskIdentifier) else { return }
        if cancelTask {
            exchange.task.cancel()
        }
        exchange.connection.cancel()
    }

    private func forwardingURL(for target: String) -> URL {
        var components = URLComponents(url: upstream, resolvingAgainstBaseURL: false) ?? URLComponents()
        let parts = target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        components.percentEncodedPath = String(parts[0])
        components.percentEncodedQuery = parts.count > 1 ? String(parts[1]) : nil
        return components.url ?? upstream
    }

    private func updateRecord(at index: Int, _ change: (inout Record) -> Void) {
        recordsLock.withLock { change(&_records[index]) }
    }
}

// MARK: - Forwarding session (callbacks on `queue`)

extension E2ERecordingProxy: URLSessionDataDelegate {
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let exchange = exchanges[dataTask.taskIdentifier], let http = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            return
        }
        updateRecord(at: exchange.recordIndex) { $0.status = http.statusCode }

        var head = "HTTP/1.1 \(http.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: http.statusCode))\r\n"
        for (key, value) in http.allHeaderFields {
            guard let name = key as? String, !Self.droppedResponseHeaders.contains(name.lowercased()) else { continue }
            head += "\(name): \(value)\r\n"
        }
        head += "Connection: close\r\n\r\n"
        exchange.connection.send(content: Data(head.utf8), completion: .contentProcessed { _ in })
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        exchanges[dataTask.taskIdentifier]?.connection.send(content: data, completion: .contentProcessed { _ in })
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // Gone already when the client closed first or `stop()` ran; nothing to record then.
        guard let exchange = exchanges.removeValue(forKey: task.taskIdentifier) else { return }
        if let error {
            updateRecord(at: exchange.recordIndex) { $0.error = error.localizedDescription }
        }
        // Ends the reply: the client reads the body until the connection closes.
        exchange.connection.send(
            content: nil,
            contentContext: .finalMessage,
            isComplete: true,
            completion: .contentProcessed { _ in exchange.connection.cancel() }
        )
    }
}

/// One HTTP/1.1 request read from a connection: complete once the head and a body of
/// `Content-Length` bytes have arrived.
private struct HTTPRequest {
    let method: String
    /// Path and query, as sent.
    let target: String
    let headers: [(String, String)]
    let body: Data

    var path: String {
        String(target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)[0])
    }

    init?(parsing buffer: Data) {
        guard let headEnd = buffer.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let head = String(decoding: buffer[buffer.startIndex..<headEnd.lowerBound], as: UTF8.self)
        var lines = head.components(separatedBy: "\r\n")
        let requestLine = lines.removeFirst().split(separator: " ")
        guard requestLine.count >= 2 else { return nil }

        var headers: [(String, String)] = []
        var contentLength = 0
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = String(line[line.startIndex..<colon])
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers.append((name, value))
            if name.lowercased() == "content-length" {
                contentLength = Int(value) ?? 0
            }
        }

        let bodyStart = headEnd.upperBound
        guard buffer.distance(from: bodyStart, to: buffer.endIndex) >= contentLength else { return nil }
        method = String(requestLine[0])
        target = String(requestLine[1])
        self.headers = headers
        body = buffer[bodyStart..<buffer.index(bodyStart, offsetBy: contentLength)]
    }
}
