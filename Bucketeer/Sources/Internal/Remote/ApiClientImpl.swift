import Foundation

final class ApiClientImpl: ApiClient {

    static let DEFAULT_REQUEST_TIMEOUT_MILLIS: Int64 = 30_000
    static let CLIENT_CLOSED_THE_CONNECTION_CODE: Int = 499
    static let DEFAULT_MAX_ATTEMPTS = 4 // 1 original try + 3 retries
    static let DEFAULT_BASE_DELAY_SECONDS = 1.0 // in seconds

    private let apiEndpoint: URL
    private let apiKey: String
    private let featureTag: String
    private let sdkInfo: SDKInfo
    private let session: Session
    private let defaultRequestTimeoutMillis: Int64
    private let logger: Logger?
    private let semaphore = DispatchSemaphore(value: 0)
    private let retrier: Retrier
    // Add this property to track the latest request generation
    private var getEvaluationsRequestId: UUID?
    private var registerEventsRequestId: UUID?
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
        retrier: Retrier,
        logger: Logger?
    ) {
        self.apiEndpoint = apiEndpoint
        self.apiKey = apiKey
        self.featureTag = featureTag
        self.sdkInfo = sdkInfo
        self.defaultRequestTimeoutMillis = defaultRequestTimeoutMills
        self.session = session
        self.logger = logger
        self.session.configuration.timeoutIntervalForRequest = TimeInterval(self.defaultRequestTimeoutMillis) / 1000
        self.retrier = retrier
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
        let timeoutMillisValue = timeoutMillis ?? defaultRequestTimeoutMillis
        // Generate a new ID for any new request call
        let newRequestId = UUID()
        self.getEvaluationsRequestId = newRequestId
        logger?.debug(message: "[API] Fetch Evaluation: \(requestBody) for requestID \(newRequestId)")
        send(
            requestId: newRequestId,
            requestBody: requestBody,
            path: ApiPaths.getEvaluations.rawValue,
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
        // Generate a new ID for any new request call
        let newRequestId = UUID()
        self.registerEventsRequestId = newRequestId
        logger?.debug(message: "[API] Register events: \(requestBody) for requestID \(newRequestId)")
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

        let timeoutMillisValue = defaultRequestTimeoutMillis
        send(
            requestId: newRequestId,
            requestBody: requestBody,
            path: ApiPaths.registerEvents.rawValue,
            timeoutMillis: timeoutMillisValue,
            encoder: encoder,
            completion: { (result: Result<(RegisterEventsResponse, URLResponse), Error>) in
                switch result {
                case .success((let response, _)):
                    completion?(.success(response))
                case .failure(let error):
                    completion?(.failure(.init(error: error).copyWith(timeoutMillis: timeoutMillisValue)))
                }
            }
        )
    }

    /// Sends a network request with automatic retry logic for transient failures.
    ///
    /// This method implements an exponential backoff retry strategy for specific error conditions.
    /// Retries are only triggered on deployment-related 499 errors
    ///
    /// - Parameters:
    ///   - requestBody: The request body to encode and send
    ///   - path: The API endpoint path to append to the base URL
    ///   - timeoutMillis: Request timeout in milliseconds
    ///   - encoder: JSON encoder for the request body (default: JSONEncoder())
    ///   - completion: Callback with the result of the request
    ///
    /// - Retry Behavior:
    ///   - **Maximum Attempts**: 4 total attempts (initial + 3 retries)
    ///   - **Retry Condition**: Only HTTP 499 status code
    ///   - **Backoff Strategy**: Exponential with base delay of 1 second
    ///   - **Queue**: Retries are scheduled asynchronously on the dispatch queue provided during initialization
    ///
    /// - Note: All other errors (network failures, HTTP 4xx/5xx codes except 499) will not trigger retries
    ///         and will be returned immediately via the completion handler.
    func send<RequestBody: Encodable, Response: Decodable>(
        requestId: UUID,
        requestBody: RequestBody,
        path: String,
        timeoutMillis: Int64,
        encoder: JSONEncoder = JSONEncoder(),
        completion: ((Result<(Response, URLResponse), Error>) -> Void)?) {
            // weak self - we don't want to retain ApiClientImpl in the retrier task closure
            // if ApiClientImpl is deallocated, the task will not be executed
            let task: Retrier.Task<(Response, URLResponse)> = { [weak self] callback in
                do {
                    guard
                        let currentRequestId = try self?.getLatestRequestId(apiPath: path)
                    else {
                        callback(.failure(
                            BKTError.illegalState(message: "Could not get latest request ID for path: \(path)")
                        ))
                        return
                    }

                    guard currentRequestId == requestId else {
                        callback(.failure(
                            BKTError.illegalState(message: "Request cancelled by newer execution")
                        ))
                        return
                    }

                    self?.sendInternal(
                        requestBody: requestBody,
                        path: path,
                        timeoutMillis: timeoutMillis,
                        encoder: encoder,
                        completion: callback
                    )
                } catch {
                    callback(.failure(error))
                }
            }

            retrier.attempt(
                task: task,
                condition: self.shouldRetry,
                maxAttempts: ApiClientImpl.DEFAULT_MAX_ATTEMPTS, // 1 original try + 3 retries
                completion: { (result: Result<(Response, URLResponse), Error>) in
                    completion?(result)
                }
            )
        }

    // noted: this method will run `synchronized`. It will blocking the current queue please do not make network call from the app main thread
    func sendInternal<RequestBody: Encodable, Response: Decodable>(
        requestBody: RequestBody,
        path: String,
        timeoutMillis: Int64,
        encoder: JSONEncoder = JSONEncoder(),
        completion: ((Result<(Response, URLResponse), Error>) -> Void)?) {
        if closed {
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

    private func shouldRetry(error: Error) -> Bool {
        if let responseError = error as? ResponseError {
            switch responseError {
            case .unacceptableCode(let code, _):
                if code == ApiClientImpl.CLIENT_CLOSED_THE_CONNECTION_CODE {
                    return true
                }
            default:
                return false
            }
        }
        return false
    }

    private func getLatestRequestId(apiPath: String) throws -> UUID? {
        guard let apiPath = ApiPaths(rawValue: apiPath) else {
            // This could happen if we add a new API path but forget to update it.
            // Throw an illegal state for an unknown path to help us catch this mistake during development.
            throw BKTError.illegalState(message: "Unknown API path: \(apiPath)")
        }
        switch apiPath {
        case .getEvaluations:
            return getEvaluationsRequestId
        case .registerEvents:
            return registerEventsRequestId
        }
    }

    /// For tests only. Sets the current `getEvaluations` request id.
    /// Not thread-safe — should be call on the SDK `dispatchQueue`.
    func setEvaluationsRequestId(_ id: UUID) {
        getEvaluationsRequestId = id
    }

    /// For tests only. Sets the current `registerEvents` request id.
    /// Not thread-safe — should be on the SDK `dispatchQueue`.
    func setRegisterEventsRequestId(_ id: UUID) {
        registerEventsRequestId = id
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
