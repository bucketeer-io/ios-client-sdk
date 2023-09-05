import UIKit
import Bucketeer

class FirstViewController: UIViewController {

    @IBOutlet weak var messageLabel: UILabel!
    var client : BKTClient?

    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            try client = BKTClient.shared
        } catch {
            // We may have an error when we did not success initialize the client
            // Handle error
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {

        messageLabel.text = client?.stringVariation(featureId: "ios_test_002", defaultValue: "not found...") ?? "not found..."

        let colorCode = client?.stringVariation(featureId: "ios_test_003", defaultValue: "#999999") ?? "#999999"
        view.backgroundColor = UIColor(hex: colorCode)
    }
    @IBAction func trackButtonAction(_ sender: Any) {
        client?.track(goalId: "ios_test_002", value: 1)
    }
    @IBAction func destroyClient(_ sender: Any) {
        try? BKTClient.destroy()
    }
    
    @IBAction func initClient(_ sender: Any) {
        let user = try! BKTUser.Builder()
            .with(id: "001")
            .with(attributes: [:])
            .build()

        do {
            try BKTClient.initialize(
                config: self.makeConfigUsingBuilder(),
                user: user
            ) { error in
                if let error {
                    print(error)
                }
            }
        } catch {
            // Handle exception when initialize the BKTClient,
            // Usually because it required to call from the main thread
            print(error.localizedDescription)
        }
    }
    private func makeConfigUsingBuilder() -> BKTConfig {
        let bundle = Bundle(for: type(of: self))
        let apiKey = ProcessInfo.processInfo.environment["API_KEY"]!
        let apiEndpoint = ProcessInfo.processInfo.environment["API_ENDPOINT"]!
        let builder = BKTConfig.Builder()
            .with(apiKey: apiKey)
            .with(apiEndpoint: apiEndpoint)
            .with(featureTag: "ios")
            .with(pollingInterval: 150_000)
            .with(appVersion: bundle.infoDictionary?["CFBundleShortVersionString"] as! String)
            .with(logger: AppLogger())

        return try! builder.build()
    }
}

extension UIColor {
    convenience init(hex: String, alpha: CGFloat) {
        let v = hex.map { String($0) } + Array(repeating: "0", count: max(6 - hex.count, 0))
        let r = CGFloat(Int(v[0] + v[1], radix: 16) ?? 0) / 255.0
        let g = CGFloat(Int(v[2] + v[3], radix: 16) ?? 0) / 255.0
        let b = CGFloat(Int(v[4] + v[5], radix: 16) ?? 0) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }

    convenience init(hex: String) {
        self.init(hex: hex, alpha: 1.0)
    }
}
