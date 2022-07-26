//
//  AuthStepItem.swift
//  MWAppAuthPlugin
//
//  Created by Jonathan Flintham on 08/01/2021.
//

import Foundation

class AuthStepItem: Codable {
    
    enum ItemType: String, Codable {
        case oauth
        case oauthRopc
        case twitter
        case modalLink
        case apple
        case button //previously modalLink
    }
    
    let type: ItemType
    let buttonTitle: String
    let oAuth2Url: String?
    let oAuth2ClientId: String?
    let oAuth2ClientSecret: String?
    let oAuth2Scope: String?
    let oAuth2RedirectScheme: String?
    let oAuth2TokenUrl: String?
    let modalLinkId: String?
    let linkId: String?
    let appleFullNameScope: Bool?
    let appleEmailScope: Bool?
    let appleAccessTokenURL: String?
    let imageURL: String?
    let text: String?
    
    init(type: ItemType, buttonTitle: String, oAuth2Url: String?, oAuth2ClientId: String?, oAuth2ClientSecret: String?, oAuth2Scope: String?, oAuth2RedirectScheme: String?, oAuth2TokenUrl: String?, modalLinkId: String?, linkId: String?, appleFullNameScope: Bool?, appleEmailScope: Bool?, appleAccessTokenURL: String?, imageURL: String?, text: String?) {

        self.type = type
        self.buttonTitle = buttonTitle
        self.oAuth2Url = oAuth2Url
        self.oAuth2ClientId = oAuth2ClientId
        self.oAuth2ClientSecret = oAuth2ClientSecret
        self.oAuth2Scope = oAuth2Scope
        self.oAuth2RedirectScheme = oAuth2RedirectScheme
        self.oAuth2TokenUrl = oAuth2TokenUrl
        self.modalLinkId = modalLinkId
        self.linkId = linkId
        self.appleFullNameScope = appleFullNameScope
        self.appleEmailScope = appleEmailScope
        self.appleAccessTokenURL = appleAccessTokenURL
        self.imageURL = imageURL
        self.text = text
    }
}

struct OAuth2Config {
    let oAuth2Url: String
    let oAuth2ClientId: String
    let oAuth2ClientSecret: String?
    let oAuth2Scope: String
    let oAuth2RedirectScheme: String
}

struct OAuthROPCConfig {
    let oAuth2TokenUrl: String
    let oAuth2ClientId: String
    let oAuth2ClientSecret: String?
    let oAuth2Scope: String?
    let imageURL: String?
    let text: String?
}

enum AuthStepItemRepresentation {
    case oauth(buttonTitle: String, config: OAuth2Config)
    case oauthRopc(buttonTitle: String, config: OAuthROPCConfig)
    case twitter(buttonTitle: String)
    case modalLink(buttonTitle: String, linkId: String)
    case apple
    
    var buttonTitle: String {
        switch self {
        case .oauth(let buttonTitle, _): return buttonTitle
        case .oauthRopc(let buttonTitle, _): return buttonTitle
        case .twitter(let buttonTitle): return buttonTitle
        case .modalLink(let buttonTitle, _): return buttonTitle
        case .apple: return ""
        }
    }
}

extension AuthStepItem {
    
    func respresentation() throws -> AuthStepItemRepresentation {
        switch self.type {
        case .oauth:
            guard let oAuth2Url = self.oAuth2Url else { throw ParseError.invalidStepData(cause: "Missing required 'oAuth2Url' parameter") }
            guard let oAuth2ClientId = self.oAuth2ClientId else { throw ParseError.invalidStepData(cause: "Missing required 'oAuth2ClientId' parameter") }
            guard let oAuth2Scope = self.oAuth2Scope else { throw ParseError.invalidStepData(cause: "Missing required 'oAuth2Scope' parameter") }
            guard let oAuth2RedirectScheme = self.oAuth2RedirectScheme else { throw ParseError.invalidStepData(cause: "Missing required 'oAuth2RedirectScheme' parameter") }
            return .oauth(buttonTitle: self.buttonTitle, config: OAuth2Config(oAuth2Url: oAuth2Url, oAuth2ClientId: oAuth2ClientId, oAuth2ClientSecret: self.oAuth2ClientSecret, oAuth2Scope: oAuth2Scope, oAuth2RedirectScheme: oAuth2RedirectScheme))
        case .oauthRopc:
            guard let oAuth2TokenUrl = self.oAuth2TokenUrl else { throw ParseError.invalidStepData(cause: "Missing required 'oAuth2TokenUrl' parameter") }
            guard let oAuth2ClientId = self.oAuth2ClientId else { throw ParseError.invalidStepData(cause: "Missing required 'oAuth2ClientId' parameter") }
            return .oauthRopc(buttonTitle: self.buttonTitle, config: OAuthROPCConfig(oAuth2TokenUrl: oAuth2TokenUrl, oAuth2ClientId: oAuth2ClientId, oAuth2ClientSecret: self.oAuth2ClientSecret, oAuth2Scope: self.oAuth2Scope, imageURL: self.imageURL, text: self.text))
        case .twitter:
            return .twitter(buttonTitle: self.buttonTitle)
        case .modalLink:
            guard let linkId = self.modalLinkId else { throw ParseError.invalidStepData(cause: "Missing required 'modalLinkId' parameter") }
            return .modalLink(buttonTitle: self.buttonTitle, linkId: linkId)
        case .button:
            guard let linkId = self.linkId else { throw ParseError.invalidStepData(cause: "Missing required 'linkId' parameter") }
            return .modalLink(buttonTitle: self.buttonTitle, linkId: linkId)
        case .apple:
            return .apple
        }
    }
}
