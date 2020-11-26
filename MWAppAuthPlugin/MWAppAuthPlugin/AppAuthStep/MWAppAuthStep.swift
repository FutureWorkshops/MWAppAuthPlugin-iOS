//
//  MWAppAuthStep.swift
//  MobileWorkflow
//
//  Created by Igor Ferreira on 14/05/2020.
//  Copyright © 2020 Future Workshops. All rights reserved.
//

import Foundation
import MobileWorkflowCore

enum L10n {
    enum AppAuth {
        static let loginTitle = "Log In"
    }
}

public enum ParseError: LocalizedError, CustomStringConvertible {
    case invalidStepData(cause: String)
    
    var code: Int {
        switch self {
        case .invalidStepData:
            return 1001
        }
    }
    
    public var domain: String {
        return "MobileWorkflow.MWAppAuthStep"
    }
    
    public var errorDescription: String? {
        return self.description
    }
    
    public var description: String {
        switch self {
        case .invalidStepData(let cause):
            return "Invalid step data: \(cause)."
        }
    }
}

class MWAppAuthStep: ORKStep {
    
    let url: String
    let clientId: String
    let clientSecret: String?
    let scope: String
    let redirectScheme: String
    let networkManager: NetworkManager
    let buttonTitle: String
    
    init(identifier: String, title: String, text: String, buttonTitle: String, url: String, clientId: String, clientSecret: String?, scope: String, redirectScheme: String, networkManager: NetworkManager) {
        self.url = url
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.scope = scope
        self.redirectScheme = redirectScheme
        self.networkManager = networkManager
        self.buttonTitle = buttonTitle
        super.init(identifier: identifier)
        self.title = title
        self.text = text
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func stepViewControllerClass() -> AnyClass {
        return MWAppAuthStepViewController.self
    }
}

extension MWAppAuthStep: MobileWorkflowStep {

    static func build(data: StepData, context: StepContext, networkManager: NetworkManager, imageLoader: ImageLoader, localizationManager: Localization) throws -> ORKStep {
        
        guard let url = data.content["oAuth2Url"] as? String else {
            throw ParseError.invalidStepData(cause: "Invalid url for \(data.identifier)")
        }
        
        // TODO: suggest these properties are injected by build variables
        // in production. They should be set remotely as a convienience only in development.
        guard let clientId = data.content["oAuth2ClientId"] as? String else {
            throw ParseError.invalidStepData(cause: "Invalid clientId for \(data.identifier)")
        }
        
        let clientSecret = data.content["oAuth2ClientSecret"] as? String // is optional
        
        guard let scope = data.content["oAuth2Scope"] as? String else {
            throw ParseError.invalidStepData(cause: "Invalid scope for \(data.identifier)")
        }
        
        guard let redirectScheme = data.content["oAuth2RedirectScheme"] as? String else {
            throw ParseError.invalidStepData(cause: "Invalid redirect scheme for \(data.identifier)")
        }
        
        guard let title = data.content["title"] as? String else {
            throw ParseError.invalidStepData(cause: "Invalid title for \(data.identifier)")
        }

        guard let text = data.content["text"] as? String else {
            throw ParseError.invalidStepData(cause: "Invalid text for \(data.identifier)")
        }

        let buttonTitle = localizationManager.translate(data.content["buttonTitle"] as? String) ?? L10n.AppAuth.loginTitle

        return MWAppAuthStep(
            identifier: data.identifier,
            title: localizationManager.translate(title) ?? title,
            text: localizationManager.translate(text) ?? text,
            buttonTitle: buttonTitle,
            url: url,
            clientId: clientId,
            clientSecret: clientSecret,
            scope: scope,
            redirectScheme: redirectScheme,
            networkManager: networkManager
        )
    }
}
