import Foundation

struct Evaluation: Equatable, Codable, Hashable {
    let id: String
    let featureId: String
    let featureVersion: Int
    let userId: String
    let variationId: String
    let variationName: String
    let variationValue: String
    let reason: Reason
}

extension Evaluation {
    func getVariationValue<T>(defaultValue: T, logger: Logger?) -> T {
        return getVariationValue(logger: logger) ?? defaultValue
    }

    func getVariationValue<T>(logger: Logger?) -> T? {
        return variationValue.getVariationValue(logger: logger)
    }
}

extension String {
    func getVariationValue<T>(logger: Logger?) -> T? {
        if T.self is BKTValue.Type {
            guard let bktValue = getVariationBKTValue(logger: logger) as? T else {
                return nil
            }
            return bktValue
        }
        return decodeValue(logger: logger)
    }

    fileprivate func decodeValue<T>(logger: Logger?) -> T? {
        let value = self
        let anyValue: Any?
        switch T.self {
        case is String.Type:
            anyValue = value
        case is Int.Type:
            anyValue = Int(value)
        case is Double.Type:
            anyValue = Double(value)
        case is Bool.Type:
            anyValue = Bool(value)
        case is [String: AnyHashable].Type:
            let data = value.data(using: .utf8) ?? Data()
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: AnyHashable]
            anyValue = json
        case is [String: BKTValue].Type:
            let data = value.data(using: .utf8) ?? Data()
            let json = (try? JSONDecoder().decode([String: BKTValue].self, from: data))
            anyValue = json
        case is [BKTValue].Type:
            let data = value.data(using: .utf8) ?? Data()
            let json = (try? JSONDecoder().decode([BKTValue].self, from: data))
            anyValue = json
        default:
            anyValue = value
        }
        guard let typedValue = anyValue as? T else {
            logger?.debug(message: "getVariation returns null reason: failed to cast \(value)")
            return nil
        }
        return typedValue
    }

    func getVariationBKTValue(logger: Logger?) -> BKTValue {
        if let dictionaryResult: [String: BKTValue] = decodeValue(logger: logger) {
            return .dictionary(dictionaryResult)
        }
        if let listResult: [BKTValue] = decodeValue(logger: logger) {
            return .list(listResult)
        }
        if let boolResult: Bool = decodeValue(logger: logger) {
            return .boolean(boolResult)
        }
        if let intResult: Int = decodeValue(logger: logger) {
            return .integer(Int64(intResult))
        }
        if let doubleResult: Double = decodeValue(logger: logger) {
            return .double(doubleResult)
        }
        return .string(self)
    }
}
