//
//  SceneDelegate.swift
//  MobileWorkflowAppAuth
//
//  Created by Igor Ferreira on 11/05/2020.
//  Copyright © 2020 Future Workshops. All rights reserved.
//

import UIKit
import MobileWorkflowCore
import MWAppAuthPlugin

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    enum SessionUserInfoKey {
        static let authRedirectHandler = "authRedirectHandler"
    }
    
    var window: UIWindow?
    private var urlSchemeManagers: [URLSchemeManager] = []
    private var rootViewController: MobileWorkflowRootViewController!
        
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        
        let manager = AppConfigurationManager(
            withPlugins: [MWAppAuthPlugin.self],
            fileManager: .default,
            authRedirectHandler: session.userInfo?[SessionUserInfoKey.authRedirectHandler] as? AuthRedirectHandler
        )
        let preferredConfigurations = self.preferredConfigurations(urlContexts: connectionOptions.urlContexts)
        self.rootViewController = MobileWorkflowRootViewController(manager: manager, preferredConfigurations: preferredConfigurations)
        
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = self.rootViewController
        window.makeKeyAndVisible()
        self.window = window
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let context = self.urlSchemeManagers.firstValidConfiguration(from: URLContexts) else { return }
        self.rootViewController.loadAppConfiguration(context)
    }
}

extension SceneDelegate {
    
    private func preferredConfigurations(urlContexts: Set<UIOpenURLContext>) -> [AppConfigurationContext] {
        
        var preferredConfigurations = [AppConfigurationContext]()
        
        if let samplePath = Bundle.main.path(forResource: "app", ofType: "json") {
            preferredConfigurations.append(.file(path: samplePath, serverId: 125, workflowId: nil, sessionValues: nil))
        }
        
        return preferredConfigurations
    }
}
