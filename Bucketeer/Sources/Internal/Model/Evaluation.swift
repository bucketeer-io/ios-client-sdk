import Foundation

struct Evaluation: Hashable, Codable {
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
        return getVariationValues(logger: logger) ?? defaultValue
    }

    func getVariationValues<T>(logger: Logger?) -> T? {
        let value = self.variationValue
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
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: AnyHashable] ?? [:]
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
}
