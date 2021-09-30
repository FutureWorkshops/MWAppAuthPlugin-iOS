//
//  OAuthSessionResponseInterceptor.swift
//  MWAppAuthPlugin
//
//  Created by Jonathan Flintham on 30/09/2021.
//

import Foundation
import MobileWorkflowCore

private let kOAuthSession = "oauth_session"

class OAuthSessionResponseInterceptor: AsyncTaskInterceptor {
    
    let credentialStore: CredentialStoreProtocol
    
    init(credentialStore: CredentialStoreProtocol) {
        self.credentialStore = credentialStore
    }
    
    func interceptResponse<T>(_ response: T, session: ContentProvider) -> T {
        guard let data = response as? Data else { return response }
        do {
            // attempt to find an oauth session in the root of the JSON response
            var json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] ?? [:]
            let sessionJson = json[kOAuthSession] as? [String: Any] ?? [:]
            guard let oauthSession = OAuthSession(json: sessionJson) else { return response }
            // create modified response with the oauth session extracted
            json[kOAuthSession] = nil
            guard let data = try JSONSerialization.data(withJSONObject: json, options: .fragmentsAllowed) as? T else { return response }
            // create and save the tokens
            var credentials = [Credential]()
            credentials.append(Credential(
                type: .token,
                value: oauthSession.accessToken,
                expirationDate: Date().addingTimeInterval(TimeInterval(oauthSession.expiresIn))
            ))
            if let refreshToken = oauthSession.refreshToken {
                credentials.append(Credential(
                    type: .refreshToken,
                    value: refreshToken,
                    expirationDate: .distantFuture
                ))
            }
            _ = self.credentialStore.updateCredentials(credentials)
            return data // return mofified response regardless of update result
        } catch {
            return response
        }
    }
}

struct OAuthSession: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
    
    let accessToken: String
    let refreshToken: String?
    let tokenType: String
    let expiresIn: Int
    
    init?(json: [String: Any]) {
        guard let accessToken = json[CodingKeys.accessToken.rawValue] as? String,
              let tokenType = json[CodingKeys.tokenType.rawValue] as? String,
              let expiresIn = json[CodingKeys.expiresIn.rawValue] as? Int
        else {
            return nil
        }
        self.accessToken = accessToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.refreshToken = json[CodingKeys.refreshToken.rawValue] as? String
    }
}
