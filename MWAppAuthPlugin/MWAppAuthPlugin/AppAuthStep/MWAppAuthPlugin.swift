//
//  MWAppAuthPlugin.swift
//  MWAppAuthPlugin
//
//  Created by Jonathan Flintham on 25/11/2020.
//

import Foundation
import MobileWorkflowCore

public struct MWAppAuthPlugin: Plugin {
    
    public static var allStepsTypes: [StepType] {
        return MWAppAuthStepType.allCases
    }
    
    public static func buildInterceptors(credentialStore: CredentialStoreProtocol) -> [AsyncTaskInterceptor] {
        return [
            RefreshTokenInterceptor(credentialStore: credentialStore)
        ]
    }
}

enum MWAppAuthStepType: String, StepType, CaseIterable {
    case networkOAuth2
    
    var typeName: String {
        return self.rawValue
    }
    
    var stepClass: BuildableStep.Type {
        switch self {
        case .networkOAuth2: return MWAppAuthStep.self
        }
    }
}

class RefreshTokenInterceptor: AsyncTaskInterceptor {
    
    let credentialStore: CredentialStoreProtocol
    
    init(credentialStore: CredentialStoreProtocol) {
        self.credentialStore = credentialStore
    }
    
    func intercept<T>(task: URLAsyncTask<T>, session: ContentProvider) -> URLAsyncTask<T> {
        return task
    }
    
    func intercept<T>(task: URLAsyncTask<T>, session: ContentProvider, networkService: AsyncTaskService, completion: @escaping (URLAsyncTask<T>) -> Void) {
        
        guard let credential = try? self.credentialStore.retrieveCredential(.token, isRequired: false).get() else {
            completion(task)
            return
        }
        
        let now = Date()
        guard now >= credential.expirationDate,
              let config = (networkService as? OAuthConfigRegister)?.retrieveOAuthConfig(),
              let refreshToken = try? self.credentialStore.retrieveCredential(.refreshToken, isRequired: false).get(),
              let tokenURL = session.resolve(url: config.tokenUrl + "/token"),
              task.input.url != tokenURL // don't intercept already running refresh task
        else {
            completion(task)
            return
        }
                
        var params: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken.value,
            "client_id": config.clientId
        ]
        if let secret = config.clientSecret {
            params["client_secret"] = secret
        }
        let paramsString = params.map({ "\($0.key)=\($0.value)" }).joined(separator: "&") // url encoding

        let refreshTask = URLAsyncTask<OAuth2RefreshTokenResponse>.build(
            url: tokenURL,
            method: .POST,
            body: paramsString.data(using: .utf8),
            session: session,
            headers: ["Content-Type": "application/x-www-form-urlencoded"],
            parser: { try OAuth2RefreshTokenResponse.parse(data: $0) }
        )
        
        networkService.perform(task: refreshTask, session: session) { [weak self] result in
            switch result {
            case .success(let response):
                let token = Credential(
                    type: CredentialType.token.rawValue,
                    value: response.accessToken,
                    expirationDate: Date().addingTimeInterval(TimeInterval(response.expiresIn))
                )
                let refresh = Credential(
                    type: CredentialType.refreshToken.rawValue,
                    value: response.refreshToken,
                    expirationDate: .distantFuture
                )
                self?.credentialStore.updateCredentials([token, refresh], completion: { [weak self] result in
                    switch result {
                    case .success:
                        let updated = task.adding(headers: ["Authorization": "Bearer \(token.value)"])
                        completion(updated)
                    case .failure(let error):
                        completion(task) // failed to update token, so complete with unmodified task
                    }
                })
            case .failure(let error):
                completion(task) // failed to update token, so complete with unmodified task
            }
        }
    }
}

struct OAuth2RefreshTokenResponse: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
    
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
}
