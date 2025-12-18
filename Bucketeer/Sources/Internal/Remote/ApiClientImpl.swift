import Foundation

final class ApiClientImpl: ApiClient {

    static let DEFAULT_REQUEST_TIMEOUT_MILLIS: Int64 = 30_000
    static let CLIENT_CLOSED_THE_CONNECTION_CODE: Int = 499
    static let DEFAULT_MAX_ATTEMPTS: Int = 3
    static let DEFAULT_BASE_DELAY_SECONDS = 1.0 // in seconds

    private let apiEndpoint: URL
    private let apiKey: String
    private let featureTag: String
    private let sdkInfo: SDKInfo
    private let session: Session
    private let defaultRequestTimeoutMills: Int64
    private let logger: Logger?
    private let semaphore = DispatchSemaphore(value: 0)
    // Dispatch queue for retry backoff, it should be the same with the SDK queue
    private let dispatchQueue: DispatchQueue
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
        sdkInfo: SDKInfo,
        defaultRequestTimeoutMills: Int64 = ApiClientImpl.DEFAULT_REQUEST_TIMEOUT_MILLIS,
        session: Session,
        queue: DispatchQueue,
        logger: Logger?
    ) {
        self.apiEndpoint = apiEndpoint
        self.apiKey = apiKey
        self.featureTag = featureTag
        self.sdkInfo = sdkInfo
        self.defaultRequestTimeoutMills = defaultRequestTimeoutMills
        self.session = session
        self.logger = logger
        self.dispatchQueue = queue
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
            sourceId: sdkInfo.sourceId,
            userEvaluationCondition: UserEvaluationCondition(
                evaluatedAt: condition.evaluatedAt,
                userAttributesUpdated: condition.userAttributesUpdated
            ),
            sdkVersion: sdkInfo.sdkVersion
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
            events: events,
            sdkVersion: sdkInfo.sdkVersion,
            sourceId: sdkInfo.sourceId
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
            completion: { [self] (result: Result<(RegisterEventsResponse, URLResponse), Error>) in
                switch result {
                case .success((let response, _)):
                    completion?(.success(response))
                case .failure(let error):
                    completion?(.failure(.init(error: error).copyWith(timeoutMillis: defaultRequestTimeoutMills)))
                }
            }
        )
    }

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

        sendRetriable(
            requestBody: requestBody,
            path: path,
            timeoutMillis: timeoutMillis,
            encoder: encoder,
            completion: completion
        )
    }

    /// Sends a network request with automatic retry logic for transient failures.
    ///
    /// This method implements an exponential backoff retry strategy for specific error conditions.
    /// Retries are only triggered for HTTP 499 (client closed connection) errors.
    ///
    /// - Parameters:
    ///   - requestBody: The request body to encode and send
    ///   - path: The API endpoint path to append to the base URL
    ///   - timeoutMillis: Request timeout in milliseconds
    ///   - encoder: JSON encoder for the request body (default: JSONEncoder())
    ///   - retryCount: Current retry attempt number (default: 0, used internally)
    ///   - completion: Callback with the result of the request
    ///
    /// - Retry Behavior:
    ///   - **Maximum Attempts**: 3 total attempts (initial + 2 retries)
    ///   - **Retry Condition**: Only HTTP 499 status code
    ///   - **Backoff Strategy**: Exponential with base delay of 1 second
    ///     - 1st retry: 1 second delay
    ///     - 2nd retry: 2 seconds delay
    ///   - **Queue**: Retries are scheduled asynchronously on the dispatch queue provided during initialization
    ///
    /// - Note: All other errors (network failures, HTTP 4xx/5xx codes except 499) will not trigger retries
    ///         and will be returned immediately via the completion handler.
    private func sendRetriable<RequestBody: Encodable, Response: Decodable>(
        requestBody: RequestBody,
        path: String,
        timeoutMillis: Int64,
        encoder: JSONEncoder = JSONEncoder(),
        retryCount: Int = 0,
        completion: ((Result<(Response, URLResponse), Error>) -> Void)?) {

        let result: Result<(Response, URLResponse), Error> = sendInternal(
            requestBody: requestBody,
            path: path,
            timeoutMillis: timeoutMillis,
            encoder: encoder
        )

        switch result {
        case .success:
            completion?(result)
        case .failure(let error):
            let maxAttempts = ApiClientImpl.DEFAULT_MAX_ATTEMPTS
            if retryCount < maxAttempts - 1 {
                var shouldRetry = false
                if let respErr = error as? ResponseError {
                    switch respErr {
                    case .unacceptableCode(let code, _):
                        // Should retry for 499 status code
                        if code == ApiClientImpl.CLIENT_CLOSED_THE_CONNECTION_CODE { shouldRetry = true }
                    default:
                        break
                    }
                }

                if shouldRetry {
                    // Exponential backoff: 1s, 2s, 4s for attempts 1, 2, 3
                    let backoff = pow(2.0, Double(retryCount)) * ApiClientImpl.DEFAULT_BASE_DELAY_SECONDS
                    let workItem = DispatchWorkItem { [weak self] in
                            self?.sendRetriable(
                                requestBody: requestBody,
                                path: path,
                                timeoutMillis: timeoutMillis,
                                encoder: encoder,
                                retryCount: retryCount + 1,
                                completion: completion
                            )
                        }
                    dispatchQueue.asyncAfter(deadline: .now() + backoff, execute: workItem)
                    return
                }
            }
            completion?(result)
        }
    }

    // noted: this method will run `synchronized`. It will blocking the current queue please do not make network call from the app main thread
    private func sendInternal<RequestBody: Encodable, Response: Decodable>(
        requestBody: RequestBody,
        path: String,
        timeoutMillis: Int64,
        encoder: JSONEncoder = JSONEncoder()) -> (Result<(Response, URLResponse), Error>) {
        if (closed) {
            return .failure(BKTError.illegalState(message: "API Client has been closed"))
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
                guard let urlResponse = urlResponse as? HTTPURLResponse else {
                    // urlResponse == nil that mean error is not from server
                    guard let error = error else {
                        // error is unknown
                        return .failure(ResponseError.unknown(urlResponse))
                    }
                    // a NSError with NSURLErrorDomain codes
                    return .failure(error)
                }

                let statusCode = urlResponse.statusCode
                guard 200..<300 ~= statusCode else {
                    // UnacceptableCode
                    let response: ErrorResponse?
                    if let data = data {
                        response = try? JSONDecoder().decode(ErrorResponse.self, from: data)
                    } else {
                        response = nil
                    }
                    let error = ResponseError.unacceptableCode(code: statusCode, response: response)
                    return .failure(error)
                }
                // Success code
                guard let data = data else {
                    return .failure(ResponseError.invalidJSONResponse(code: statusCode, error: nil))
                }
                do {
                    let response = try JSONDecoder().decode(Response.self, from: data)
                    return .success((response, urlResponse))
                } catch let error {
                    return .failure(ResponseError.invalidJSONResponse(code: statusCode, error: error))
                }
            }

            let requestHandler : (Result<(Response, URLResponse), Error>) -> Void = { [weak self] data in
                result = data
                // unlock from network queue
                self?.logger?.debug(message: "[API] Resource available")
                self?.semaphore.signal()
            }

            // session.task runs asynchronously on URLSession's background thread/queue, NOT on io.bucketeer.taskQueue.
            // Without semaphore.wait() below, sendInternal would return immediately, allowing the next queued operation
            // on io.bucketeer.taskQueue to execute before this network request completes.
            // The semaphore blocks io.bucketeer.taskQueue until the completion handler calls semaphore.signal(),
            // ensuring serial execution of network requests across the SDK.
            session.task(with: request) { data, urlResponse, error in
                let output = responseParser(data, urlResponse, error)
                requestHandler(output)
            }

            logger?.debug(message: "[API] RequestID wait: \(requestId)")
            semaphore.wait()
            logger?.debug(message: "[API] RequestID finished: \(requestId)")
            guard let finalResult = result else {
                return .failure(BKTError.illegalState(message: "fail to handle the request result"))
            }
            // Success
            return finalResult
        } catch let error {
            // catch error may throw before sending the request
            // runtime error will handle in the session callback
            // so that we will not required call `semephore.signal()` here
            logger?.debug(message: "[API] RequestID: \(requestId) could not request with error \(error.localizedDescription)")
            return .failure(error)
        }
    }

    func cancelAllOngoingRequest() {
        // we access API client from the SDK queue only, so its safe
        closed = true
        session.invalidateAndCancel()
    }
}

enum ResponseError: Error {
    case invalidJSONResponse(code: Int, error: Error?)
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
