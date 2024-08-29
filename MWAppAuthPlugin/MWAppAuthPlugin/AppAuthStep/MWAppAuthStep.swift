//
//  MWAppAuthStep.swift
//  MobileWorkflow
//
//  Created by Igor Ferreira on 14/05/2020.
//  Copyright © 2020 Future Workshops. All rights reserved.
//

import Foundation
import MobileWorkflowCore
import UIKit

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
            guard let item = self.items[safe: indexPath.row] else { fallthrough }
            switch item.type {
            case .apple: return SignInWithAppleButtonTableViewCell.defaultReuseIdentifier
            case .modalLink,
                 .button,
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
            imageCell.configure(backgroundImage: nil, animated: false)
            return
        }
        
        if indexPath.section == 1 {
            guard let subtitleCell = cell as? MWSubtitleTableViewCell else { preconditionFailure() }
            let resolvedText = self.session.resolve(value: self.text ?? "")
            subtitleCell.viewData = .init(title: resolvedText, subtitle: nil, image: nil, willLoadImage: false, isDisclosureIndictorHidden: true)
            return
        }
        
        guard let item = self.items[safe: indexPath.row],
              let representation = try? item.respresentation()
        else {
            preconditionFailure()
        }
        
        switch representation {
        case .oauth(let buttonTitle, _):
            guard let buttonCell = cell as? MWButtonTableViewCell else {
                preconditionFailure()
            }
            buttonCell.configureButton(label: buttonTitle, style: .primary, theme: self.theme)
        case .oauthRopc(let buttonTitle, _):
            guard let buttonCell = cell as? MWButtonTableViewCell else {
                preconditionFailure()
            }
            buttonCell.configureButton(label: buttonTitle, style: .primary, theme: self.theme)
        case .twitter(let buttonTitle):
            guard let buttonCell = cell as? MWButtonTableViewCell else {
                preconditionFailure()
            }
            buttonCell.configureButton(label: buttonTitle, style: .primary, theme: self.theme)
        case .modalLink(let buttonTitle, _):
            guard let buttonCell = cell as? MWButtonTableViewCell else {
                preconditionFailure()
            }
            buttonCell.configureButton(label: buttonTitle, style: .outline, theme: self.theme)
        case .apple:
            guard let buttonCell = cell as? SignInWithAppleButtonTableViewCell else {
                preconditionFailure()
            }
            buttonCell.theme = self.theme
        }
    }
}

extension MWAppAuthStep: BuildableStep {

    static var mandatoryCodingPaths: [CodingKey] {
        /// Each type has a different set of mandatory properties, and these are covered by proprety-specific errors thrown by `representation()` method in `AuthStepItem`.
        [["items": ["type"]]]
    }
    
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
            
            /// Currently secondary modalLink/button items use property 'label', whereas main item uses 'buttonTitle'.
            /// This should be made constistent, but for now we'll check for both.
            var buttonTitle = localizationService.translate(content[first: ["buttonTitle", "label"]] as? String) ?? ""
            if buttonTitle.isEmpty {
                buttonTitle = typeAsString.capitalized
            }
            
            let oAuth2Url = content["oAuth2Url"] as? String
            let oAuth2ClientId = content["oAuth2ClientId"] as? String
            let oAuth2ClientSecret = content["oAuth2ClientSecret"] as? String
            let oAuth2Scope = content["oAuth2Scope"] as? String
            let oAuth2RedirectScheme = content["oAuth2RedirectScheme"] as? String
            let oAuth2TokenUrl = content["oAuth2TokenUrl"] as? String
            
            let modalLinkId = content.getString(key: "modalLinkId")
            let linkId = content.getString(key: "linkId")
            
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
                modalLinkId: modalLinkId,
                linkId: linkId,
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

public struct SignInSignInItem: Codable {
    let label: String
    let oAuth2ClientId: String
    let oAuth2ClientSecret: String
    let oAuth2Scope: String
    let appleAccessTokenURL: String?
    let appleEmailScope: String?
    let appleFullNameScope: String?
    let imageURL: String?
    let oAuth2RedirectScheme: String?
    let oAuth2TokenUrl: String?
    let oAuth2Url: String?
    let text: String?
    let type: String?
    
    public static func signInSignInItem(
        label: String,
        oAuth2ClientId: String,
        oAuth2ClientSecret: String,
        oAuth2Scope: String,
        appleAccessTokenURL: String? = nil,
        appleEmailScope: String? = nil,
        appleFullNameScope: String? = nil,
        imageURL: String? = nil,
        oAuth2RedirectScheme: String? = nil,
        oAuth2TokenUrl: String? = nil,
        oAuth2Url: String? = nil,
        text: String? = nil,
        type: String? = nil
    ) -> SignInSignInItem {
        return SignInSignInItem(label: label, oAuth2ClientId: oAuth2ClientId, oAuth2ClientSecret: oAuth2ClientSecret, oAuth2Scope: oAuth2Scope, appleAccessTokenURL: appleAccessTokenURL, appleEmailScope: appleEmailScope, appleFullNameScope: appleFullNameScope, imageURL: imageURL, oAuth2RedirectScheme: oAuth2RedirectScheme, oAuth2TokenUrl: oAuth2TokenUrl, oAuth2Url: oAuth2Url, text: text, type: type)
    }
    
    public static func signInSignInROPCItem(
        label: String,
        oAuth2ClientId: String,
        oAuth2ClientSecret: String,
        oAuth2Scope: String,
        oAuth2TokenUrl: String,
        imageURL: String? = nil,
        text: String? = nil
    ) -> SignInSignInItem {
        return SignInSignInItem(label: label, oAuth2ClientId: oAuth2ClientId, oAuth2ClientSecret: oAuth2ClientSecret, oAuth2Scope: oAuth2Scope, appleAccessTokenURL: nil, appleEmailScope: nil, appleFullNameScope: nil, imageURL: imageURL, oAuth2RedirectScheme: nil, oAuth2TokenUrl: oAuth2TokenUrl, oAuth2Url: nil, text: text, type: AuthStepItem.ItemType.oauthRopc.rawValue)
    }
    
    public static func signInSignInOauthItem(
        label: String,
        oAuth2ClientId: String,
        oAuth2ClientSecret: String,
        oAuth2Scope: String,
        oAuth2RedirectScheme: String,
        oAuth2Url: String,
        imageURL: String? = nil,
        oAuth2TokenUrl: String? = nil,
        text: String? = nil
    ) -> SignInSignInItem {
        return SignInSignInItem(label: label, oAuth2ClientId: oAuth2ClientId, oAuth2ClientSecret: oAuth2ClientSecret, oAuth2Scope: oAuth2Scope, appleAccessTokenURL: nil, appleEmailScope: nil, appleFullNameScope: nil, imageURL: imageURL, oAuth2RedirectScheme: oAuth2RedirectScheme, oAuth2TokenUrl: oAuth2TokenUrl, oAuth2Url: oAuth2Url, text: text, type: AuthStepItem.ItemType.oauth.rawValue)
    }
}

public class SignInSignInMetadata: StepMetadata {
    enum CodingKeys: String, CodingKey {
        case options = "items"
        case imageURL
        case text
    }
    
    let options: [SignInSignInItem]
    let imageURL: String?
    let text: String?
    
    init(id: String, title: String, options: [SignInSignInItem], imageURL: String?, text: String?, next: PushLinkMetadata?, links: [LinkMetadata]) {
        self.options = options
        self.imageURL = imageURL
        self.text = text
        super.init(id: id, type: "networkOAuth2", title: title, next: next, links: links)
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.options = try container.decode([SignInSignInItem].self, forKey: .options)
        self.imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        self.text = try container.decodeIfPresent(String.self, forKey: .text)
        try super.init(from: decoder)
    }
    
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.options, forKey: .options)
        try container.encodeIfPresent(self.imageURL, forKey: .imageURL)
        try container.encodeIfPresent(self.text, forKey: .text)
        try super.encode(to: encoder)
    }
}

public extension StepMetadata {
    static func appAuthStep(
        id: String,
        title: String,
        options: [SignInSignInItem],
        imageURL: String? = nil,
        text: String? = nil,
        next: PushLinkMetadata? = nil,
        links: [LinkMetadata] = []
    ) -> SignInSignInMetadata {
        SignInSignInMetadata(
            id: id,
            title: title,
            options: options,
            imageURL: imageURL,
            text: text,
            next: next,
            links: links
        )
    }
}
