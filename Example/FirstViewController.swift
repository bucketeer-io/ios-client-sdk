import UIKit
import FirebaseMessaging
import Bucketeer

class FirstViewController: UIViewController {

    @IBOutlet weak var messageLabel: UILabel!

    private let streamingSwitch = UISwitch()
    private var updateListenerKey: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            _ = try BKTClient.shared
        } catch {
            // We may have an error when we did not success initialize the client
            // Handle error
        }
        setUpStreamingSwitch()
        addUpdateListener()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        refreshFlagValues()
        
        requestPushNotificationPermission()
    }

    private func refreshFlagValues() {
        let client = try? BKTClient.shared
        messageLabel.text = client?.stringVariation(featureId: "ios_test_002", defaultValue: "not found...") ?? "not found..."

        let colorCode = client?.stringVariation(featureId: "ios_test_003", defaultValue: "#999999") ?? "#999999"
        view.backgroundColor = UIColor(hex: colorCode)
    }
    @IBAction func trackButtonAction(_ sender: Any) {
        let client = try? BKTClient.shared
        client?.track(goalId: "ios_test_002", value: 1)
    }
    @IBAction func destroyClient(_ sender: Any) {
        try? BKTClient.destroy()
        updateListenerKey = nil
    }
    
    @IBAction func initClient(_ sender: Any) {
        let user = try! BKTUser.Builder()
            .with(id: "user_001")
            .with(attributes: [:])
            .build()

        do {
            try BKTClient.initialize(
                config: self.makeConfigUsingBuilder(),
                user: user
            ) { [weak self] error in
                if let error {
                    print(error)
                }
                DispatchQueue.main.async {
                    self?.addUpdateListener()
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
        print("Initializing BKTClient with streaming \(StreamingMode.isOn ? "enabled" : "disabled")...")
        let builder = BKTConfig.Builder()
            .with(apiKey: bundle.infoDictionary?["API_KEY"] as! String)
            .with(apiEndpoint: bundle.infoDictionary?["API_ENDPOINT"] as! String)
            .with(featureTag: "ios")
            .with(pollingInterval: 60_000)
            .with(enableStreaming: StreamingMode.isOn)
            .with(appVersion: bundle.infoDictionary?["CFBundleShortVersionString"] as! String)
            .with(logger: AppLogger())

        return try! builder.build()
    }

    @IBAction func switchUser(_ sender: Any) {
        let destroyAndInitialize: () -> Void = {
            do {
                print("[Bucketeer] destroying ---------- ")
                try BKTClient.destroy()
                self.updateListenerKey = nil
                
                // create new user with new userId
                let user = try! BKTUser.Builder()
                    .with(id: "user_002")
                    .with(attributes: [:])
                    .build()
                let config = self.makeConfigUsingBuilder()
                
                print("[Bucketeer] initializing ---------- ")
                try BKTClient.initialize(config: config, user: user) { error in
                    DispatchQueue.main.async {
                        if let error {
                            print("[Bucketeer] ERROR initialize ------------------", error)
                        } else {
                            print("[Bucketeer] OK initialize ------------------")
                        }
                        self.addUpdateListener()
                    }
                }
            } catch {
                print("[Bucketeer] ERROR trying to destroy and initialize ------------------")
            }
        }
        if let client = try? BKTClient.shared {
            client.track(goalId: "ios_test_002", value: 1)
            print("[Bucketeer] flushing ---------- ")
            client.flush { error in
                if let error {
                    print("[Bucketeer] ERROR flushing ------------------", error)
                    return
                }
                print("[Bucketeer] OK flushing ------------------")
                destroyAndInitialize()
            }
        } else {
            destroyAndInitialize()
        }
    }
    
    func requestPushNotificationPermission() {
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { [weak self] result, err in
                if result {
                    self?.onGrantedNotificationPermission()
                }
            }
        )

        UIApplication.shared.registerForRemoteNotifications()
    }
    
    func onGrantedNotificationPermission() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: { [weak self] in
            Messaging.messaging().token { token, error in
                if let token = token, token.count > 0 {
                    self?.subscribeToTopic()
                }
            }
        })
    }
    
    // In order to receive the update notification when the flag value changed
    // We need subscribe to topic, with the topic name is in this format bucketeer-<YOUR_FEATURE_TAG>
    // Please add your Firebase project's GoogleService-Info.plist to the target `Example` before test this.
    func subscribeToTopic() {
        let tag = "ios"
        let topic = "bucketeer-\(tag)"
        Messaging.messaging().subscribe(toTopic: topic) { error in
            if let error = error {
                print("Subscribed to \(topic) topic failed with error: \(error)")
            } else {
                print("Subscribed to \(topic) topic")
            }
        }
    }

    private func setUpStreamingSwitch() {
        let title = UILabel()
        title.text = "Streaming"
        streamingSwitch.isOn = StreamingMode.isOn
        streamingSwitch.addTarget(self, action: #selector(streamingSwitchChanged), for: .valueChanged)

        let stack = UIStackView(arrangedSubviews: [title, streamingSwitch])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    // Destroys the client and starts it again, so the new mode applies to a fresh client.
    @objc private func streamingSwitchChanged(_ sender: UISwitch) {
        StreamingMode.isOn = sender.isOn
        sender.isEnabled = false
        let user = (try? BKTClient.shared.currentUser()) ?? (try! BKTUser.Builder()
            .with(id: "user_001")
            .with(attributes: [:])
            .build())
        do {
            try BKTClient.destroy()
            updateListenerKey = nil
            try BKTClient.initialize(config: makeConfigUsingBuilder(), user: user) { [weak self] error in
                DispatchQueue.main.async {
                    if let error {
                        print(error)
                    }
                    self?.addUpdateListener()
                    self?.refreshFlagValues()
                    sender.isEnabled = true
                }
            }
        } catch {
            print(error.localizedDescription)
            sender.isEnabled = true
        }
    }

    private func addUpdateListener() {
        guard let client = try? BKTClient.shared else { return }
        if let key = updateListenerKey {
            client.removeEvaluationUpdateListener(key: key)
        }
        updateListenerKey = client.addEvaluationUpdateListener(listener: self)
    }
}

extension FirstViewController: EvaluationUpdateListener {
    // The SDK calls this on the main thread after the flag values change.
    func onUpdate() {
        refreshFlagValues()
        print("Evaluation updated. ios_test_002 = \(messageLabel.text ?? "")")
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
