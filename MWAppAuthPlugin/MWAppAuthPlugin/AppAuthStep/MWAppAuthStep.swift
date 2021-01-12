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

private let kImageCellReuseIdentifier = "ImageCellReuseIdentifier"
private let kAuthCellReuseIdentifier = "AuthCellReuseIdentifier"

class MWAppAuthStep: ORKTableStep, UITableViewDelegate {
    
    let imageURL: String?
    let services: MobileWorkflowServices
    
    init(identifier: String, title: String, text: String?, imageURL: String?, items: [AuthItem], services: MobileWorkflowServices) {
        self.imageURL = (imageURL?.isEmpty ?? true) ? nil : imageURL
        self.services = services
        super.init(identifier: identifier)
        self.title = title
        self.text = text
        self.items = items
    }
    
    override func reuseIdentifierForRow(at indexPath: IndexPath) -> String {
        guard let _ = self.imageURL else { return kAuthCellReuseIdentifier }
        switch indexPath.section {
        case 0: return kImageCellReuseIdentifier
        case 1: return kAuthCellReuseIdentifier
        default: return kAuthCellReuseIdentifier
        }
    }
    
    override func registerCells(for tableView: UITableView) {
        tableView.register(MobileWorkflowImageTableViewCell.self, forCellReuseIdentifier: kImageCellReuseIdentifier)
        tableView.register(MobileWorkflowButtonTableViewCell.self, forCellReuseIdentifier: kAuthCellReuseIdentifier)
    }
    
    override func numberOfSections() -> Int {
        guard let _ = self.imageURL else { return 1 }
        return 2
    }
    
    override func numberOfRows(inSection section: Int) -> Int {
        guard let _ = self.imageURL else { return self.items?.count ?? 0 }
        switch section {
        case 0: return 1
        case 1: return self.items?.count ?? 0
        default: return 0
        }
    }
    
    override func configureCell(_ cell: UITableViewCell, indexPath: IndexPath, tableView: UITableView) {
        if let _ = imageURL, indexPath.section == 0 {
            guard let imageCell = cell as? MobileWorkflowImageTableViewCell else { preconditionFailure() }
            imageCell.backgroundImage = nil
            return
        }
        
        guard let item = self.objectForRow(at: indexPath) as? AuthItem,
              let representation = try? item.respresentation(),
              let buttonCell = cell as? MobileWorkflowButtonTableViewCell
        else {
            preconditionFailure()
        }
        
        switch representation {
        case .oauth(let buttonTitle, _):
            buttonCell.configureButton(label: buttonTitle, style: .primary)
        case .twitter(let buttonTitle):
            buttonCell.configureButton(label: buttonTitle, style: .primary)
        case .modalWorkflowId(let buttonTitle, _):
            buttonCell.configureButton(label: buttonTitle, style: .outline)
        }
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
        let imageURL = data.content["imageURL"] as? String
        
        let itemsContent = data.content["items"] as? [[String: Any]] ?? []
        let items: [AuthItem] = try itemsContent.map { content in
            let typeAsString = content["type"] as? String ?? "NO_TYPE"
            guard let type = AuthItem.ItemType(rawValue: typeAsString) else {
                throw ParseError.unsupportedItemType(type: typeAsString)
            }
            
            var buttonTitle = localizationService.translate(content["buttonTitle"] as? String) ?? ""
            if buttonTitle.isEmpty {
                buttonTitle = typeAsString.capitalized
            }
            
            let oAuth2Url = content["oAuth2Url"] as? String
            let oAuth2ClientId = content["oAuth2ClientId"] as? String
            let oAuth2ClientSecret = content["oAuth2ClientSecret"] as? String
            let oAuth2Scope = content["oAuth2Scope"] as? String
            let oAuth2RedirectScheme = content["oAuth2RedirectScheme"] as? String
            
            let modalWorkflowId: Int?
            if let id = content["modalWorkflowId"] as? String, id.isEmpty == false {
                modalWorkflowId = Int(id)
            } else {
                modalWorkflowId = content["modalWorkflowId"] as? Int
            }
            
            let item = AuthItem(
                type: type,
                buttonTitle: buttonTitle,
                oAuth2Url: oAuth2Url,
                oAuth2ClientId: oAuth2ClientId,
                oAuth2ClientSecret: oAuth2ClientSecret,
                oAuth2Scope: oAuth2Scope,
                oAuth2RedirectScheme: oAuth2RedirectScheme,
                modalWorkflowId: modalWorkflowId
            )
            
            _ = try item.respresentation() // confirm valid representation
            
            return item
        }
        
        return MWAppAuthStep(
            identifier: data.identifier,
            title: localizationService.translate(title) ?? title,
            text: localizationService.translate(text),
            imageURL: imageURL,
            items: items,
            services: services
        )
    }
}
