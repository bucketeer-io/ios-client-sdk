import UIKit
import Bucketeer
import UserNotifications

import FirebaseCore
import FirebaseMessaging

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    var viewControllers: [UIViewController] = []
    let isFeatureFlagUpdatedKey = "bucketeer_feature_flag_updated"
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        configureFirebaseMessage()
        
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
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        // Print full message.
        print(userInfo)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        // TODO: Handle data of notification
        
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)
        
        if let isFeatureFlagUpdated = userInfo[isFeatureFlagUpdatedKey] as? String, isFeatureFlagUpdated == "true" {
            print("isFeatureFlagUpdated: \(isFeatureFlagUpdated)")
            // Please make sure the BKTClient has been initialize before access it
            if let client = try? BKTClient.shared {
                client.fetchEvaluations(timeoutMillis: 15, completion: { err in
                    guard err == nil else { return }
                    let testRealtimeUpdateFeatureFlag = "fcm-feature"
                    let showNewFeature = client.stringVariation(featureId: testRealtimeUpdateFeatureFlag, defaultValue: "")
                    print("Bucketeer feature flag new value: \(showNewFeature)")
                    if (showNewFeature == "okay") {
                        // The Application code to show the new feature
                    } else {
                        // The code to run when the feature is off
                    }
                })
            }
        }
        // Print full message.
        print(userInfo)
        completionHandler(.newData)
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Unable to register for remote notifications: \(error.localizedDescription)")
    }
    
    // This function is added here only for debugging purposes, and can be removed if swizzling is enabled.
    // If swizzling is disabled then this function must be implemented so that the APNs token can be paired to
    // the FCM registration token.
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("APNs token retrieved: \(deviceToken)")
    }
    
    func configureFirebaseMessage() {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    // Receive displayed notifications for iOS 10 devices.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        // Print full message.
        print(userInfo)
        
        // Change this to your preferred presentation option
        completionHandler([[.alert, .sound]])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        // Print full message.
        print(userInfo)
    }
}

extension AppDelegate: MessagingDelegate {
    // [START refresh_token]
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(String(describing: fcmToken))")
        
        let dataDict: [String: String] = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(
            name: Notification.Name("FCMToken"),
            object: nil,
            userInfo: dataDict
        )
        // TODO: If necessary send token to application server.
        // Note: This callback is fired at each app startup and whenever a new token is generated.
    }
    
    // [END refresh_token]
}
