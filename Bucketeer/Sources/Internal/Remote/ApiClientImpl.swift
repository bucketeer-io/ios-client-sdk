import Foundation

final class ApiClientImpl: ApiClient {

    static let DEFAULT_REQUEST_TIMEOUT_MILLIS: Int64 = 30_000

    private let apiEndpoint: URL
    private let apiKey: String
    private let featureTag: String
    private let session: Session
    private let defaultRequestTimeoutMills: Int64
    private let logger: Logger?

    init(
        apiEndpoint: URL,
        apiKey: String,
        featureTag: String,
        defaultRequestTimeoutMills: Int64 = ApiClientImpl.DEFAULT_REQUEST_TIMEOUT_MILLIS,
        session: Session = URLSession.shared,
        logger: Logger?) {

        self.apiEndpoint = apiEndpoint
        self.apiKey = apiKey
        self.featureTag = featureTag
        self.defaultRequestTimeoutMills = defaultRequestTimeoutMills
        self.session = session
        self.logger = logger
        self.session.configuration.timeoutIntervalForRequest = TimeInterval(self.defaultRequestTimeoutMills) / 1000
    }

    func getEvaluations(user: User, userEvaluationsId: String, timeoutMillis: Int64?, completion: ((GetEvaluationsResult) -> Void)?) {
        let startAt = Date()
        let requestBody = GetEvaluationsRequestBody(
            tag: self.featureTag,
            user: user,
            userEvaluationsId: userEvaluationsId,
            sourceId: .ios
        )
        let featureTag = self.featureTag
        logger?.debug(message: "[API] Fetch Evaluation: \(requestBody)")
        send(
            requestBody: requestBody,
            path: "get_evaluations",
            timeoutMillis: timeoutMillis ?? defaultRequestTimeoutMills,
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
                    completion?(.failure(error: .init(error: error), featureTag: featureTag))
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
                    completion?(.failure(.init(error: error)))
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

            session.task(with: request) { data, urlResponse, error in
                guard let data = data else {
                    guard let error = error else {
                        completion?(.failure(ResponseError.unknown(urlResponse)))
                        return
                    }
                    completion?(.failure(error))
                    return
                }

                guard let urlResponse = urlResponse as? HTTPURLResponse else {
                    completion?(.failure(ResponseError.unknown(urlResponse)))
                    return
                }
                do {
                    guard 200..<300 ~= urlResponse.statusCode else {
                        let response: ErrorResponse? = try JSONDecoder().decode(ErrorResponse.self, from: data)
                        let error = ResponseError.unacceptableCode(code: urlResponse.statusCode, response: response)
                        completion?(.failure(error))
                        return
                    }
                    let response = try JSONDecoder().decode(Response.self, from: data)
                    completion?(.success((response, urlResponse)))
                } catch let error {
                    completion?(.failure(error))
                }
            }
        } catch let error {
            completion?(.failure(error))
        }
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
