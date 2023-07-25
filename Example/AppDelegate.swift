import UIKit
import Bucketeer

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var viewControllers: [UIViewController] = []

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        let user = try! BKTUser.Builder()
            .with(id: "001")
            .with(attributes: [:])
            .build()

        BKTClient.initialize(
            config: self.makeConfigUsingBuilder(),
            user: user
        ) { error in
            if let error {
                print(error)
            }
            
            let client = try? BKTClient.shared
            client.updateUserAttributes(attributes: [:])
            print("intVariation =", client.intVariation(featureId: "feature-ios-e2e-integer", defaultValue: 0))
            print("doubleVariation =", client.doubleVariation(featureId: "feature-ios-e2e-double", defaultValue: 0.0))
            print("boolVariation =", client.boolVariation(featureId: "feature-ios-e2e-bool", defaultValue: false))
            print("stringVariation =", client.stringVariation(featureId: "feature-ios-e2e-string", defaultValue: "004 not found..."))
            print("jsonVariation =", client.jsonVariation(featureId: "feature-ios-e2e-json", defaultValue: [:]))
            
            DispatchQueue.main.async {
                self.setSingleViewController()
            }

            DispatchQueue.main.async {
                let isTabMode = client.boolVariation(featureId: "ios_test_001", defaultValue: false)
                if isTabMode {
                    self.setTabBarController()
                } else {
                    self.setSingleViewController()
                }
            }
        }

        return true
    }

    private func makeConfigUsingBuilder() -> BKTConfig {
        let bundle = Bundle(for: type(of: self))
        let apiKey = ProcessInfo.processInfo.environment["API_KEY"]!
        let apiEndpoint = ProcessInfo.processInfo.environment["API_ENDPOINT"]!
        let builder = BKTConfig.Builder()
            .with(apiKey: apiKey)
            .with(apiEndpoint: apiEndpoint)
            .with(featureTag: "ios")
            .with(pollingInterval: 5_000)
            .with(appVersion: bundle.infoDictionary?["CFBundleShortVersionString"] as! String)

        return try! builder.build()
    }
    
    private func makeConfig() -> BKTConfig {
        let bundle = Bundle(for: type(of: self))
        let apiKey = ProcessInfo.processInfo.environment["API_KEY"]!
        let apiEndpoint = ProcessInfo.processInfo.environment["API_ENDPOINT"]!

        return try! BKTConfig(
            apiKey: apiKey,
            apiEndpoint: apiEndpoint,
            featureTag: "ios",
            pollingInterval: 5_000,
            appVersion: bundle.infoDictionary?["CFBundleShortVersionString"] as! String,
            logger: nil
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
