import UIKit
import Bucketeer

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var viewControllers: [UIViewController] = []

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        if #available(iOS 13.0, tvOS 13.0, *) {
            BKTBackgroundTask.enable()
        }
        
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
                var client : BKTClient?
                do {
                    try client = BKTClient.shared
                } catch {
                    print(error.localizedDescription)
                }
                client?.updateUserAttributes(attributes: [:])
                print("intVariation =", client?.intVariation(featureId: "feature-ios-e2e-integer", defaultValue: 0) ?? 0)
                print("doubleVariation =", client?.doubleVariation(featureId: "feature-ios-e2e-double", defaultValue: 0.0) ?? 0.0)
                print("boolVariation =", client?.boolVariation(featureId: "feature-ios-e2e-bool", defaultValue: false) ?? false)
                print("stringVariation =", client?.stringVariation(featureId: "feature-ios-e2e-string", defaultValue: "004 not found...") ?? "004 not found...")
                print("jsonVariation =", client?.jsonVariation(featureId: "feature-ios-e2e-json", defaultValue: [:]) ?? [:])
                DispatchQueue.main.async {
                    self.setSingleViewController()
                }

                DispatchQueue.main.async {
                    let isTabMode = client?.boolVariation(featureId: "ios_test_001", defaultValue: false) ?? false
                    if isTabMode {
                        self.setTabBarController()
                    } else {
                        self.setSingleViewController()
                    }
                }
            }
        } catch {
            // Handle exception when initialize the BKTClient,
            // Usually because it required to call from the main thread
            print(error.localizedDescription)
        }
            

        return true
    }

    private func makeConfigUsingBuilder() -> BKTConfig {
        let bundle = Bundle(for: type(of: self))
        let builder = BKTConfig.Builder()
            .with(apiKey: bundle.infoDictionary?["API_KEY"] as! String)
            .with(apiEndpoint: bundle.infoDictionary?["API_ENDPOINT"] as! String)
            .with(featureTag: "ios")
            .with(pollingInterval: 150_000)
            .with(appVersion: bundle.infoDictionary?["CFBundleShortVersionString"] as! String)
            .with(logger: AppLogger())

        return try! builder.build()
    }
    
    private func makeConfig() -> BKTConfig {
        let bundle = Bundle(for: type(of: self))
        return try! BKTConfig(
            apiKey: bundle.infoDictionary?["API_KEY"] as! String,
            apiEndpoint: bundle.infoDictionary?["API_ENDPOINT"] as! String,
            featureTag: "ios",
            pollingInterval: 150_000,
            appVersion: bundle.infoDictionary?["CFBundleShortVersionString"] as! String,
            logger: AppLogger()
        )
    }

    private func setSingleViewController() {
        guard self.window?.rootViewController is SplashViewController else { return }

        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        let firstViewController = storyboard.instantiateViewController(withIdentifier: "FirstViewController")
        let navigationController = UINavigationController(rootViewController: firstViewController)

        self.window?.rootViewController = navigationController
        self.window?.makeKeyAndVisible()
    }

    private func setTabBarController() {
        guard self.window?.rootViewController is SplashViewController else { return }

        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        let firstViewController = storyboard.instantiateViewController(withIdentifier: "FirstViewController")
        firstViewController.tabBarItem = UITabBarItem(tabBarSystemItem: .featured, tag: 1)
        viewControllers.append(firstViewController)

        let secondViewController = storyboard.instantiateViewController(withIdentifier: "SecondViewController")
        secondViewController.tabBarItem = UITabBarItem(tabBarSystemItem: .history, tag: 2)
        viewControllers.append(secondViewController)

        let thirdViewController = storyboard.instantiateViewController(withIdentifier: "ThirdViewController")
        thirdViewController.tabBarItem = UITabBarItem(tabBarSystemItem: .downloads, tag: 3)
        viewControllers.append(thirdViewController)

        let tabBarController = UITabBarController()
        tabBarController.setViewControllers(viewControllers, animated: false)

        window?.rootViewController = tabBarController
        window?.makeKeyAndVisible()
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}
