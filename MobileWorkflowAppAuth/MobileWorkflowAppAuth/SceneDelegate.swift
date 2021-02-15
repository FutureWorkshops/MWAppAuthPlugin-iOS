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

class SceneDelegate: MobileWorkflowSceneDelegate {
    
    override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        self.dependencies.plugins = [MWAppAuthPlugin.self]
        
        super.scene(scene, willConnectTo: session, options: connectionOptions)
    }
}
