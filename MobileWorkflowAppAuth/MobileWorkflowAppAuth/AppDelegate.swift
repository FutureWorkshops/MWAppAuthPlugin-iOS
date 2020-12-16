//
//  AppDelegate.swift
//  MobileWorkflowAppAuth
//
//  Copyright © Future Workshops. All rights reserved.
//

import UIKit
import MobileWorkflowCore

#if DEBUG
#else
func debugPrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {}
func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {}
#endif

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    weak var eventDelegate: AppDelegateEventDelegate?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        self.eventDelegate?.application(app, open: url, options: options) ?? false
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        self.eventDelegate?.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        self.eventDelegate?.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }
}
