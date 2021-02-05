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
class AppDelegate: UIResponder, UIApplicationDelegate, AppEventDelegator {

    weak var eventDelegate: AppEventDelegate?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
