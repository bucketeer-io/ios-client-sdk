import Foundation

enum StreamingMode {
    // Starts from ENABLE_STREAMING in environment.xcconfig ("YES" turns it on, anything else turns it off).
    // The switch on the first screen changes it while the app is running.
    static var isOn: Bool = Bundle.main.infoDictionary?["ENABLE_STREAMING"] as? String == "YES"
}
