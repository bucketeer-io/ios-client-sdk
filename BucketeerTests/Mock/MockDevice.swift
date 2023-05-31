import Foundation
@testable import Bucketeer

final class MockDevice: Device {
    var osVersion: String = "16.0"
    var model: String = "iPhone14,7"
    var type: String = "mobile"
}
