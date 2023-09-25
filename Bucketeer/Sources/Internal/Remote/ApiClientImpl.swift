import Foundation

final class ApiClientImpl: ApiClient {

    static let DEFAULT_REQUEST_TIMEOUT_MILLIS: Int64 = 30_000

    private let apiEndpoint: URL
    private let apiKey: String
    private let featureTag: String
    private let session: Session
    private let defaultRequestTimeoutMills: Int64
    private let logger: Logger?
    private let semaphore = DispatchSemaphore(value: 0)
    private var closed = false

    deinit {
        // over-signaling does not introduce new problems
        // https://stackoverflow.com/questions/70457141/safe-to-signal-semaphore-before-deinitialization-just-in-case
        semaphore.signal()
    }

    init(
        apiEndpoint: URL,
        apiKey: String,
        featureTag: String,
        defaultRequestTimeoutMills: Int64 = ApiClientImpl.DEFAULT_REQUEST_TIMEOUT_MILLIS,
        session: Session,
        logger: Logger?
    ) {

        self.apiEndpoint = apiEndpoint
        self.apiKey = apiKey
        self.featureTag = featureTag
        self.defaultRequestTimeoutMills = defaultRequestTimeoutMills
        self.session = session
        self.logger = logger
        self.session.configuration.timeoutIntervalForRequest = TimeInterval(self.defaultRequestTimeoutMills) / 1000
    }

    func getEvaluations(
        user: User,
        userEvaluationsId: String,
        timeoutMillis: Int64?,
        condition: UserEvaluationCondition,
        completion: ((GetEvaluationsResult) -> Void)?) {
        let startAt = Date()
        let requestBody = GetEvaluationsRequestBody(
            tag: self.featureTag,
            user: user,
            userEvaluationsId: userEvaluationsId,
            sourceId: .ios,
            userEvaluationCondition: UserEvaluationCondition(evaluatedAt: condition.evaluatedAt,
                                                             userAttributesUpdated: condition.userAttributesUpdated)
        )
        let featureTag = self.featureTag
        let timeoutMillisValue = timeoutMillis ?? defaultRequestTimeoutMills
        logger?.debug(message: "[API] Fetch Evaluation: \(requestBody)")
        send(
            requestBody: requestBody,
            path: "get_evaluations",
            timeoutMillis: timeoutMillisValue,
            completion: { (result: Result<(GetEvaluationsResponse, URLResponse), Error>) in
                switch result {
                case .success((var response, let urlResponse)):
                    let endAt = Date()
                    let latencySecond = endAt.timeIntervalSince(startAt)
                    response.seconds = latencySecond
                    let contentLength = urlResponse.expectedContentLength
                    response.sizeByte = contentLength
                    response.featureTag = featureTag
                    completion?(.success(response))
                case .failure(let error):
                    completion?(.failure(error: .init(error: error).copyWith(timeoutMillis: timeoutMillisValue), featureTag: featureTag))
                }
            }
        )
    }

    func registerEvents(events: [Event], completion: ((Result<RegisterEventsResponse, BKTError>) -> Void)?) {
        let requestBody = RegisterEventsRequestBody(
            events: events
        )
        logger?.debug(message: "[API] Register events: \(requestBody)")
        let encoder = JSONEncoder()
        if #available(iOS 13.0, tvOS 13.0, *) {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        }
        encoder.keyEncodingStrategy = .custom({ keys in
            if keys.last?.stringValue == "protobufType", let key = AnyKey(stringValue: "@type") {
                return key
            }
            return keys.last ?? keys[0]
        })

        send(
            requestBody: requestBody,
            path: "register_events",
            timeoutMillis: defaultRequestTimeoutMills,
            encoder: encoder,
            completion: { (result: Result<(RegisterEventsResponse, URLResponse), Error>) in
                switch result {
                case .success((let response, _)):
                    completion?(.success(response))
                case .failure(let error):
                    completion?(.failure(.init(error: error).copyWith(timeoutMillis: defaultRequestTimeoutMills)))
                }
            }
        )
    }

    // noted: this method will run `synchronized`. It will blocking the current queue please do not call it from the app main thread
    func send<RequestBody: Encodable, Response: Decodable>(
        requestBody: RequestBody,
        path: String,
        timeoutMillis: Int64,
        encoder: JSONEncoder = JSONEncoder(),
        completion: ((Result<(Response, URLResponse), Error>) -> Void)?) {
        if (closed) {
            completion?(.failure(BKTError.illegalState(message: "API Client has been closed")))
            return
        }

        let requestId = Date().unixTimestamp
        logger?.debug(message: "[API] RequestID enqueue: \(requestId)")
        logger?.debug(message: "[API] Register events: \(requestBody)")
        do {
            if #available(iOS 11.0, *) {
                encoder.outputFormatting = [encoder.outputFormatting, .prettyPrinted, .sortedKeys]
            }

            let body = try encoder.encode(requestBody)
            var request = URLRequest(url: apiEndpoint.appendingPathComponent(path))
            request.httpMethod = "POST"
            request.allHTTPHeaderFields = [
                "Authorization": self.apiKey,
                "Content-Type": "application/json"
            ]
            request.httpBody = body
            request.timeoutInterval = TimeInterval(timeoutMillis) / 1000
            // `result` shared resource between the network queue and the SDK queue
            var result : Result<(Response, URLResponse), Error>?
            let responseParser : (Data?, URLResponse?, Error?) -> Result<(Response, URLResponse), Error> = { data, urlResponse, error in
                guard let data = data else {
                    guard let error = error else {
                        return .failure(ResponseError.unknown(urlResponse))
                    }
                    return .failure(error)
                }

                guard let urlResponse = urlResponse as? HTTPURLResponse else {
                    return .failure(ResponseError.unknown(urlResponse))
                }
                do {
                    guard 200..<300 ~= urlResponse.statusCode else {
                        let response: ErrorResponse? = try JSONDecoder().decode(ErrorResponse.self, from: data)
                        let error = ResponseError.unacceptableCode(code: urlResponse.statusCode, response: response)
                        return .failure(error)
                    }
                    let response = try JSONDecoder().decode(Response.self, from: data)
                    return .success((response, urlResponse))
                } catch let error {
                    return .failure(error)
                }
            }

            let requestHandler : (Result<(Response, URLResponse), Error>) -> Void = { [weak self] data in
                result = data
                // unlock from network queue
                self?.logger?.debug(message: "[API] Resource available")
                self?.semaphore.signal()
            }

            session.task(with: request) { data, urlResponse, error in
                let output = responseParser(data, urlResponse, error)
                requestHandler(output)
            }

            logger?.debug(message: "[API] RequestID wait: \(requestId)")
            semaphore.wait()
            logger?.debug(message: "[API] RequestID finished: \(requestId)")
            guard result != nil else {
                completion?(.failure(BKTError.illegalState(message: "fail to handle the request result")))
                return
            }
            completion?(result!)
        } catch let error {
            // catch error may throw before sending the request
            // runtime error will handle in the session callback
            // so that we will not required call `semephore.signal()` here
            logger?.debug(message: "[API] RequestID: \(requestId) could not request with error \(error.localizedDescription)")
            completion?(.failure(error))
        }
    }

    func cancelAllOngoingRequest() {
        // we access API client from the SDK queue only, so its safe
        closed = true
        session.invalidateAndCancel()
    }
}

enum ResponseError: Error {
    case unknown(URLResponse?)
    case unacceptableCode(code: Int, response: ErrorResponse?)
}

private struct AnyKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

private typealias UnixTimestamp = Int

fileprivate extension Date {
    /// Date to Unix timestamp.
    var unixTimestamp: UnixTimestamp {
        return UnixTimestamp(self.timeIntervalSince1970 * 1_000) // millisecond precision
    }
}

fileprivate extension UnixTimestamp {
    /// Unix timestamp to date.
    var date: Date {
        return Date(timeIntervalSince1970: TimeInterval(self / 1_000)) // must take a millisecond-precise Unix timestamp
    }
}

extension BKTError {
    func copyWith(timeoutMillis: Int64) -> BKTError {
        switch self {
        case .timeout(let m, let e, _):
            return .timeout(message: m, error: e, timeoutMillis: timeoutMillis)
        default:
            return self
        }
    }
}
