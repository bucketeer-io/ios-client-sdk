import UIKit
import Bucketeer

class FirstViewController: UIViewController {

    @IBOutlet weak var messageLabel: UILabel!

    override func viewWillAppear(_ animated: Bool) {
        messageLabel.text = BKTClient.shared.stringVariation(featureId: "ios_test_002", defaultValue: "not found...")

        let colorCode = BKTClient.shared.stringVariation(featureId: "ios_test_003", defaultValue: "#999999")
        view.backgroundColor = UIColor(hex: colorCode)
    }
    @IBAction func trackButtonAction(_ sender: Any) {
        BKTClient.shared.track(goalId: "ios_test_002", value: 1)
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
