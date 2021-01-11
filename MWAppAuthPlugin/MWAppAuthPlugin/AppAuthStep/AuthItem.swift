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
private let kModalWorkflowId = "modalWorkflowId"

class AuthItem: NSObject, Codable, NSCopying, NSCoding, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }
    
    enum ItemType: String, Codable {
        case oauth
        case twitter
        case modalWorkflow
    }
    
    let type: ItemType
    let buttonTitle: String
    let oAuth2Url: String?
    let oAuth2ClientId: String?
    let oAuth2ClientSecret: String?
    let oAuth2Scope: String?
    let oAuth2RedirectScheme: String?
    let modalWorkflowId: Int?
    
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
        let modalWorkflowId = coder.decodeObject(of: NSNumber.self, forKey: kModalWorkflowId)
        
        self.init(
            type: type,
            buttonTitle: buttonTitle as String,
            oAuth2Url: oAuth2Url as String?,
            oAuth2ClientId: oAuth2ClientId as String?,
            oAuth2ClientSecret: oAuth2ClientSecret as String?,
            oAuth2Scope: oAuth2Scope as String?,
            oAuth2RedirectScheme: oAuth2RedirectScheme as String?,
            modalWorkflowId: modalWorkflowId?.intValue
        )
    }
    
    init(type: ItemType, buttonTitle: String, oAuth2Url: String?, oAuth2ClientId: String?, oAuth2ClientSecret: String?, oAuth2Scope: String?, oAuth2RedirectScheme: String?, modalWorkflowId: Int?) {

        self.type = type
        self.buttonTitle = buttonTitle
        self.oAuth2Url = oAuth2Url
        self.oAuth2ClientId = oAuth2ClientId
        self.oAuth2ClientSecret = oAuth2ClientSecret
        self.oAuth2Scope = oAuth2Scope
        self.oAuth2RedirectScheme = oAuth2RedirectScheme
        self.modalWorkflowId = modalWorkflowId
        
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
        coder.encode(self.modalWorkflowId, forKey: kModalWorkflowId)
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
            modalWorkflowId: self.modalWorkflowId
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

enum AuthItemRepresentation {
    case oauth(buttonTitle: String, config: OAuth2Config)
    case twitter(buttonTitle: String)
    case modalWorkflowId(buttonTitle: String, modalWorkflowId: Int)
    
    var buttonTitle: String {
        switch self {
        case .oauth(let buttonTitle, _): return buttonTitle
        case .twitter(let buttonTitle): return buttonTitle
        case .modalWorkflowId(let buttonTitle, _): return buttonTitle
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
        case .twitter:
            return .twitter(buttonTitle: self.buttonTitle)
        case .modalWorkflow:
            guard let modalWorkflowId = self.modalWorkflowId else {
                throw ParseError.invalidStepData(cause: "Missing modalWorkflowId")
            }
            return .modalWorkflowId(buttonTitle: self.buttonTitle, modalWorkflowId: modalWorkflowId)
        }
    }
}