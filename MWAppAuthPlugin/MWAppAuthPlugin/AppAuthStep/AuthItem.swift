//
//  AuthItem.swift
//  MWAppAuthPlugin
//
//  Created by Jonathan Flintham on 08/01/2021.
//

import Foundation

private let kType = "type"
private let kButtonTitle = "buttonTitle"
private let kOAuth2Url = "oAuth2Url"
private let kOAuth2ClientId = "oAuth2ClientId"
private let kOAuth2ClientSecret = "oAuth2ClientSecret"
private let kOAuth2Scope = "oAuth2Scope"
private let kOAuth2RedirectScheme = "oAuth2RedirectScheme"
private let kOAuth2TokenUrl = "oAuth2TokenUrl"
private let kModalWorkflowId = "modalWorkflowId"
private let kAppleFullNameScope = "appleFullNameScope"
private let kAppleEmailScope = "appleEmailScope"
private let kAppleAccessTokenURL = "appleAccessTokenURL"

class AuthItem: NSObject, Codable, NSCopying, NSCoding, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }
    
    enum ItemType: String, Codable {
        case oauth
        case oauthRopc
        case twitter
        case modalWorkflow
        case apple
    }
    
    let type: ItemType
    let buttonTitle: String
    let oAuth2Url: String?
    let oAuth2ClientId: String?
    let oAuth2ClientSecret: String?
    let oAuth2Scope: String?
    let oAuth2RedirectScheme: String?
    let oAuth2TokenUrl: String?
    let modalWorkflowId: Int?
    let appleFullNameScope: Bool?
    let appleEmailScope: Bool?
    let appleAccessTokenURL: String?
    
    public required convenience init?(coder: NSCoder) {
        
        let typeAsString = coder.decodeObject(of: NSString.self, forKey: kType) ?? "NO_TYPE"
        guard let type = ItemType(rawValue: typeAsString as String) else {
            preconditionFailure(L10n.AppAuth.unsupportedItemTypeError(type: typeAsString as String))
        }
        
        guard let buttonTitle = coder.decodeObject(of: NSString.self, forKey: kButtonTitle) else {
            preconditionFailure(L10n.AppAuth.invalidStepDataError(cause: "Missing buttonTitle"))
        }
        
        let oAuth2Url = coder.decodeObject(of: NSString.self, forKey: kOAuth2Url)
        let oAuth2ClientId = coder.decodeObject(of: NSString.self, forKey: kOAuth2ClientId)
        let oAuth2ClientSecret = coder.decodeObject(of: NSString.self, forKey: kOAuth2ClientSecret)
        let oAuth2Scope = coder.decodeObject(of: NSString.self, forKey: kOAuth2Scope)
        let oAuth2RedirectScheme = coder.decodeObject(of: NSString.self, forKey: kOAuth2RedirectScheme)
        let oAuth2TokenUrl = coder.decodeObject(of: NSString.self, forKey: kOAuth2TokenUrl)
        let modalWorkflowId = coder.decodeObject(of: NSNumber.self, forKey: kModalWorkflowId)
        let appleFullNameScope = coder.decodeObject(forKey: kAppleFullNameScope) as? Bool
        let appleEmailScope = coder.decodeObject(forKey: kAppleEmailScope) as? Bool
        let appleAccessTokenURL = coder.decodeObject(of: NSString.self, forKey: kAppleAccessTokenURL)
        
        self.init(
            type: type,
            buttonTitle: buttonTitle as String,
            oAuth2Url: oAuth2Url as String?,
            oAuth2ClientId: oAuth2ClientId as String?,
            oAuth2ClientSecret: oAuth2ClientSecret as String?,
            oAuth2Scope: oAuth2Scope as String?,
            oAuth2RedirectScheme: oAuth2RedirectScheme as String?,
            oAuth2TokenUrl: oAuth2TokenUrl as String?,
            modalWorkflowId: modalWorkflowId?.intValue,
            appleFullNameScope: appleFullNameScope,
            appleEmailScope: appleEmailScope,
            appleAccessTokenURL: appleAccessTokenURL as String?
        )
    }
    
    init(type: ItemType, buttonTitle: String, oAuth2Url: String?, oAuth2ClientId: String?, oAuth2ClientSecret: String?, oAuth2Scope: String?, oAuth2RedirectScheme: String?, oAuth2TokenUrl: String?, modalWorkflowId: Int?, appleFullNameScope: Bool?, appleEmailScope: Bool?, appleAccessTokenURL: String?) {

        self.type = type
        self.buttonTitle = buttonTitle
        self.oAuth2Url = oAuth2Url
        self.oAuth2ClientId = oAuth2ClientId
        self.oAuth2ClientSecret = oAuth2ClientSecret
        self.oAuth2Scope = oAuth2Scope
        self.oAuth2RedirectScheme = oAuth2RedirectScheme
        self.oAuth2TokenUrl = oAuth2TokenUrl
        self.modalWorkflowId = modalWorkflowId
        self.appleFullNameScope = appleFullNameScope
        self.appleEmailScope = appleEmailScope
        self.appleAccessTokenURL = appleAccessTokenURL
        
        super.init()
    }
    
    public func encode(with coder: NSCoder) {
        coder.encode(self.type.rawValue as NSString, forKey: kType)
        coder.encode(self.buttonTitle as NSString?, forKey: kButtonTitle)
        coder.encode(self.oAuth2Url as NSString?, forKey: kOAuth2Url)
        coder.encode(self.oAuth2ClientId as NSString?, forKey: kOAuth2ClientId)
        coder.encode(self.oAuth2ClientSecret as NSString?, forKey: kOAuth2ClientSecret)
        coder.encode(self.oAuth2Scope as NSString?, forKey: kOAuth2Scope)
        coder.encode(self.oAuth2RedirectScheme as NSString?, forKey: kOAuth2RedirectScheme)
        coder.encode(self.oAuth2TokenUrl as? NSString?, forKey: kOAuth2TokenUrl)
        coder.encode(self.modalWorkflowId, forKey: kModalWorkflowId)
        coder.encode(self.appleFullNameScope, forKey: kAppleFullNameScope)
        coder.encode(self.appleEmailScope, forKey: kAppleEmailScope)
        coder.encode(self.appleAccessTokenURL, forKey: kAppleAccessTokenURL)
    }
    
    public func copy(with zone: NSZone? = nil) -> Any {
        return AuthItem(
            type: self.type,
            buttonTitle: self.buttonTitle,
            oAuth2Url: self.oAuth2Url,
            oAuth2ClientId: self.oAuth2ClientId,
            oAuth2ClientSecret: self.oAuth2ClientSecret,
            oAuth2Scope: self.oAuth2Scope,
            oAuth2RedirectScheme: self.oAuth2RedirectScheme,
            oAuth2TokenUrl: self.oAuth2TokenUrl,
            modalWorkflowId: self.modalWorkflowId,
            appleFullNameScope: self.appleEmailScope,
            appleEmailScope: self.appleEmailScope,
            appleAccessTokenURL: self.appleAccessTokenURL
        )
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
}

enum AuthItemRepresentation {
    case oauth(buttonTitle: String, config: OAuth2Config)
    case oauthRopc(buttonTitle: String, config: OAuthROPCConfig)
    case twitter(buttonTitle: String)
    case modalWorkflowId(buttonTitle: String, modalWorkflowId: Int)
    case apple
    
    var buttonTitle: String {
        switch self {
        case .oauth(let buttonTitle, _): return buttonTitle
        case .oauthRopc(let buttonTitle, _): return buttonTitle
        case .twitter(let buttonTitle): return buttonTitle
        case .modalWorkflowId(let buttonTitle, _): return buttonTitle
        case .apple: return ""
        }
    }
}

extension AuthItem {
    
    func respresentation() throws -> AuthItemRepresentation {
        switch self.type {
        case .oauth:
            guard let oAuth2Url = self.oAuth2Url, let oAuth2ClientId = self.oAuth2ClientId, let oAuth2Scope = self.oAuth2Scope, let oAuth2RedirectScheme = self.oAuth2RedirectScheme else {
                throw ParseError.invalidStepData(cause: "Missing required OAuth2 parameters")
            }
            return .oauth(buttonTitle: self.buttonTitle, config: OAuth2Config(oAuth2Url: oAuth2Url, oAuth2ClientId: oAuth2ClientId, oAuth2ClientSecret: self.oAuth2ClientSecret, oAuth2Scope: oAuth2Scope, oAuth2RedirectScheme: oAuth2RedirectScheme))
        case .oauthRopc:
            guard let oAuth2TokenUrl = self.oAuth2TokenUrl, let oAuth2ClientId = self.oAuth2ClientId else {
                throw ParseError.invalidStepData(cause: "Missing required OAuth2 parameters")
            }
            return .oauthRopc(buttonTitle: self.buttonTitle, config: OAuthROPCConfig(oAuth2TokenUrl: oAuth2TokenUrl, oAuth2ClientId: oAuth2ClientId, oAuth2ClientSecret: self.oAuth2ClientSecret))
        case .twitter:
            return .twitter(buttonTitle: self.buttonTitle)
        case .modalWorkflow:
            guard let modalWorkflowId = self.modalWorkflowId else {
                throw ParseError.invalidStepData(cause: "Missing modalWorkflowId")
            }
            return .modalWorkflowId(buttonTitle: self.buttonTitle, modalWorkflowId: modalWorkflowId)
        case .apple:
            return .apple
        }
    }
}
