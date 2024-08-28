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
        let value = self
        let anyValue: Any?
        switch T.self {
        case is String.Type:
            anyValue = value
        case is Int.Type:
            if let doubleValue = Double(value) {
                anyValue = Int(doubleValue)
            } else {
                anyValue = nil
            }
        case is Double.Type:
            anyValue = Double(value)
        case is Bool.Type:
            anyValue = Bool(value)
        case is [String: AnyHashable].Type:
            let data = value.data(using: .utf8) ?? Data()
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: AnyHashable]
            anyValue = json
        case is BKTValue.Type:
            anyValue = getVariationBKTValue()
        default:
            anyValue = value
        }
        guard let typedValue = anyValue as? T else {
            logger?.debug(message: "getVariation returns null reason: failed to cast \(value)")
            return nil
        }
        return typedValue
    }

    func getVariationBKTValue() -> BKTValue {
        let value = self
        let data = value.data(using: .utf8) ?? Data()
        if let valueResult = (try? JSONDecoder().decode(BKTValue.self, from: data)), valueResult != .null {
            return valueResult
        }
        return .string(self)
    }
}
