import UIKit

protocol Device {
    var osVersion: String { get }
    var model: String { get }
    var type: String { get }
}

final class DeviceImpl: Device {
    let osVersion: String = UIDevice.current.systemVersion

    /// Device model name. See `identifier` on https://www.theiphonewiki.com/wiki/Models
    let model: String = {
        var systemInfo = utsname()
        uname(&systemInfo)

        let identifier = Mirror(reflecting: systemInfo.machine).children.reduce(into: "") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else {
                return
            }
            identifier.append(String(UnicodeScalar(UInt8(value))))
        }
        return identifier
    }()

    var type: String {
        model.contains("TV") ? "tv" : "mobile"
    }
}
