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
        static func invalidStepDataError(cause: String) -> String {
            "Invalid step data: \(cause)"
        }
        static func unsupportedItemTypeError(type: String) -> String {
            "Unsupported item type: \(type)"
        }
    }
}

public enum ParseError: LocalizedError {
    case invalidStepData(cause: String)
    case unsupportedItemType(type: String)
    
    public var errorDescription: String? {
        return self.description
    }
    
    public var description: String {
        switch self {
        case .invalidStepData(let cause):
            return L10n.AppAuth.invalidStepDataError(cause: cause)
        case .unsupportedItemType(let type):
            return L10n.AppAuth.unsupportedItemTypeError(type: type)
        }
    }
}

class MWAppAuthStep: ORKStep {
    
    let items: [AuthItem]
    let services: MobileWorkflowServices
    
    init(identifier: String, title: String, text: String?, items: [AuthItem], services: MobileWorkflowServices) {
        self.items = items
        self.services = services
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

    static func build(step: StepInfo, services: MobileWorkflowServices) throws -> ORKStep {
        let data = step.data
        let localizationService = services.localizationService
        
        guard let title = data.content["title"] as? String else {
            throw ParseError.invalidStepData(cause: "No title found for \(data.identifier)")
        }

        let text = data.content["text"] as? String
        
        let itemsContent = data.content["items"] as? [[String: Any]] ?? []
        let items: [AuthItem] = try itemsContent.map { content in
            let typeAsString = content["type"] as? String ?? "NO_TYPE"
            guard let type = AuthItem.ItemType(rawValue: typeAsString) else {
                throw ParseError.unsupportedItemType(type: typeAsString)
            }
            
            let buttonTitle = localizationService.translate(data.content["buttonTitle"] as? String) ?? L10n.AppAuth.loginTitle
            
            let oAuth2Url = content["oAuth2Url"] as? String
            let oAuth2ClientId = content["oAuth2ClientId"] as? String
            let oAuth2ClientSecret = content["oAuth2ClientSecret"] as? String
            let oAuth2Scope = content["oAuth2Scope"] as? String
            let oAuth2RedirectScheme = content["oAuth2RedirectScheme"] as? String
            
            let modalWorkflowId = content["modalWorkflowId"] as? Int
            
            return AuthItem(
                type: type,
                buttonTitle: buttonTitle,
                oAuth2Url: oAuth2Url,
                oAuth2ClientId: oAuth2ClientId,
                oAuth2ClientSecret: oAuth2ClientSecret,
                oAuth2Scope: oAuth2Scope,
                oAuth2RedirectScheme: oAuth2RedirectScheme,
                modalWorkflowId: modalWorkflowId
            )
        }
        
        return MWAppAuthStep(
            identifier: data.identifier,
            title: localizationService.translate(title) ?? title,
            text: localizationService.translate(text),
            items: items,
            services: services
        )
    }
}
