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

class SceneDelegate: MWSceneDelegate {
    
    override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        self.dependencies.plugins = [MWAppAuthPluginStruct.self]
        
        super.scene(scene, willConnectTo: session, options: connectionOptions)
    }
    
    override func preferredConfigurations(urlContexts: Set<UIOpenURLContext>) -> [AppConfigurationContext] {
        return [.config(app, serverId: 125)]
    }
}
