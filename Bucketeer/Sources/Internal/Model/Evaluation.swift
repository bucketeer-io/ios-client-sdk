import Foundation

struct Evaluation: Hashable, Codable {
    let id: String
    let featureId: String
    let featureVersion: Int
    let userId: String
    let variationId: String
    var variation: Variation
    let reason: Reason
    var variationValue: String
}

extension Evaluation {
    func getVariationValue<T>(defaultValue: T, logger: Logger?) -> T {
        let value = self.variationValue
        let anyValue: Any?
        switch defaultValue {
        case is String:
            anyValue = value
        case is Int:
            anyValue = Int(value)
        case is Double:
            anyValue = Double(value)
        case is Bool:
            anyValue = Bool(value)
        case is [String: AnyHashable]:
            let data = value.data(using: .utf8) ?? Data()
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: AnyHashable] ?? [:]
            anyValue = json
        default:
            anyValue = value
        }
        guard let typedValue = anyValue as? T else {
            logger?.debug(message: "getVariation returns null reason: failed to cast \(value)")
            return defaultValue
        }
        return typedValue
    }
}
