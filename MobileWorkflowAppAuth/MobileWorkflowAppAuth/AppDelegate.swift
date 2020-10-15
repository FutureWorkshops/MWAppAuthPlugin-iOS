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
class AppDelegate: UIResponder, UIApplicationDelegate, AuthRedirector {
    
    weak var authFlowResumer: AuthFlowResumer?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }
    
    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        
        connectingSceneSession.userInfo = [SceneDelegate.SessionUserInfoKey.authRedirectHandler: self.authRedirectHandler()]
        
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return self.handleAuthRedirect(for: url)
    }

}
