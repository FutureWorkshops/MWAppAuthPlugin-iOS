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
        static let loginTitle = "Continue"
        static func invalidStepDataError(cause: String) -> String {
            "Invalid step data: \(cause)"
        }
        static func unsupportedItemTypeError(type: String) -> String {
            "Unsupported item type: \(type)"
        }
        static let loginDetailsTitle = "Please enter your login details:"
        static let usernameFieldTitle = "Username"
        static let passwordFieldTitle = "Password"
        static let required = "Required"
        static let unauthorisedAlertTitle = "Unauthorised"
        static let unauthorisedAlertMessage = "Incorrect email or password. Please try again."
        static let unauthorisedAlertButton = "OK"
    }
    
    enum AppleLogin {
        static let errorTitle = "Error"
        static let errorMessage = "Something went wrong. We couldn't validate your Apple credentials"
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

enum AuthScope: String, Codable {
    case email
    case fullName
}

class MWAppAuthStep: MWStep, TableStep {
    
    var items: [AuthStepItem]
    let imageURL: String?
    let services: StepServices
    let session: Session
    
    init(identifier: String, text: String?, imageURL: String?, items: [AuthStepItem], services: StepServices, session: Session) {
        self.items = items
        self.imageURL = (imageURL?.isEmpty ?? true) ? nil : imageURL
        self.services = services
        self.session = session
        super.init(identifier: identifier)
        self.text = text
        
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func instantiateViewController() -> StepViewController {
        MWAppAuthStepViewController(tableStep: self)
    }
    
    // MARK: TableStep
    
    var style: UITableView.Style {
        return .plain
    }
    
    var hasNavigationFooterInTableFooter: Bool {
        return false
    }
    
    func reuseIdentifierForTableRow(at indexPath: IndexPath) -> String {
        switch indexPath.section {
        case 0: return MWImageTableViewCell.defaultReuseIdentifier
        case 1: return MWSubtitleTableViewCell.defaultReuseIdentifier
        case 2:
            guard let item = self.items[safe: indexPath.row] as? AuthStepItem else { fallthrough }
            switch item.type {
            case .apple: return SignInWithAppleButtonTableViewCell.defaultReuseIdentifier
            case .modalWorkflow,
                 .oauth,
                 .oauthRopc,
                 .twitter: return MWButtonTableViewCell.defaultReuseIdentifier
            }
        default: return MWButtonTableViewCell.defaultReuseIdentifier
        }
    }
    
    func registerTableCells(for tableView: UITableView) {
        tableView.register(MWImageTableViewCell.self)
        tableView.register(MWSubtitleTableViewCell.self)
        tableView.register(MWButtonTableViewCell.self)
        tableView.register(SignInWithAppleButtonTableViewCell.self)
    }
    
    func configureTableCell(_ cell: UITableViewCell, indexPath: IndexPath, tableView: UITableView) {
        if indexPath.section == 0 {
            guard let imageCell = cell as? MWImageTableViewCell else { preconditionFailure() }
            imageCell.backgroundImage = nil
            return
        }
        
        if indexPath.section == 1 {
            guard let subtitleCell = cell as? MWSubtitleTableViewCell else { preconditionFailure() }
            let resolvedText = self.session.resolve(value: self.text ?? "")
            subtitleCell.viewData = .init(title: resolvedText, subtitle: nil, image: nil, willLoadImage: false, isDisclosureIndictorHidden: true)
            return
        }
        
        guard let item = self.items[safe: indexPath.row] as? AuthStepItem,
              let representation = try? item.respresentation()
        else {
            preconditionFailure()
        }
        
        switch representation {
        case .oauth(let buttonTitle, _):
            guard let buttonCell = cell as? MWButtonTableViewCell else {
                preconditionFailure()
            }
            buttonCell.configureButton(label: buttonTitle, style: .primary)
        case .oauthRopc(let buttonTitle, _):
            guard let buttonCell = cell as? MWButtonTableViewCell else {
                preconditionFailure()
            }
            buttonCell.configureButton(label: buttonTitle, style: .primary)
        case .twitter(let buttonTitle):
            guard let buttonCell = cell as? MWButtonTableViewCell else {
                preconditionFailure()
            }
            buttonCell.configureButton(label: buttonTitle, style: .primary)
        case .modalWorkflowId(let buttonTitle, _):
            guard let buttonCell = cell as? MWButtonTableViewCell else {
                preconditionFailure()
            }
            buttonCell.configureButton(label: buttonTitle, style: .outline)
        case .apple:
            break // no configuration required
        }
    }
}

extension MWAppAuthStep: BuildableStep {

    static func build(stepInfo: StepInfo, services: StepServices) throws -> Step {
        let data = stepInfo.data
        let localizationService = services.localizationService

        let text = data.content["text"] as? String
        let imageURL = data.content["imageURL"] as? String
        
        let itemsContent = data.content["items"] as? [[String: Any]] ?? []
        let items: [AuthStepItem] = try itemsContent.map { content in
            let typeAsString = content["type"] as? String ?? "NO_TYPE"
            guard let type = AuthStepItem.ItemType(rawValue: typeAsString) else {
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
            let oAuth2TokenUrl = content["oAuth2TokenUrl"] as? String
            
            let modalWorkflowId = content.getString(key: "modalWorkflowId")
            
            let appleFullNameScope = content["appleFullNameScope"] as? Bool
            let appleEmailScope = content["appleEmailScope"] as? Bool
            let appleAccessTokenURL = content["appleAccessTokenURL"] as? String
            
            let itemImageURL = content["imageURL"] as? String
            let itemText = content["text"] as? String
            
            let item = AuthStepItem(
                type: type,
                buttonTitle: buttonTitle,
                oAuth2Url: oAuth2Url,
                oAuth2ClientId: oAuth2ClientId,
                oAuth2ClientSecret: oAuth2ClientSecret,
                oAuth2Scope: oAuth2Scope,
                oAuth2RedirectScheme: oAuth2RedirectScheme,
                oAuth2TokenUrl: oAuth2TokenUrl,
                modalWorkflowId: modalWorkflowId,
                appleFullNameScope: appleFullNameScope,
                appleEmailScope: appleEmailScope,
                appleAccessTokenURL: appleAccessTokenURL,
                imageURL: itemImageURL,
                text: itemText
            )
            
            _ = try item.respresentation() // confirm valid representation

            return item
        }
        
        return MWAppAuthStep(
            identifier: data.identifier,
            text: localizationService.translate(text),
            imageURL: imageURL,
            items: items,
            services: services,
            session: stepInfo.session
        )
    }
}

extension MWAppAuthStep: InterceptorConfigurator {
    
    func configureInterceptors(interceptors: [AsyncTaskInterceptor]) {
        let refreshTokenInterceptors = interceptors.compactMap({ $0 as? RefreshTokenInterceptor })
        guard !refreshTokenInterceptors.isEmpty else { return }
        
        if let item = self.items.first(where: { [AuthStepItem.ItemType.oauth, .oauthRopc].contains($0.type) }),
           let tokenUrl = item.oAuth2Url,
           let clientId = item.oAuth2ClientId
        {
            let config = OAuthRefreshTokenConfig(
                tokenUrl: tokenUrl,
                clientId: clientId,
                clientSecret: item.oAuth2ClientSecret
            )
            refreshTokenInterceptors.forEach {
                $0.config = config
            }
        }
    }
}
