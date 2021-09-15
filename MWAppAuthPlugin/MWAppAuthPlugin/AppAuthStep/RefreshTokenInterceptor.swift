//
//  RefreshTokenInterceptor.swift
//  MWAppAuthPlugin
//
//  Created by Jonathan Flintham on 15/09/2021.
//

import Foundation
import MobileWorkflowCore

struct OAuthRefreshTokenConfig {
    public let tokenUrl: String
    public let clientId: String
    public let clientSecret: String?
    
    public init(tokenUrl: String, clientId: String, clientSecret: String?) {
        self.tokenUrl = tokenUrl
        self.clientId = clientId
        self.clientSecret = clientSecret
    }
}

struct OAuthRefreshTokenResponse: Decodable {
    
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

class RefreshTokenInterceptor: AsyncTaskInterceptor {
    
    let credentialStore: CredentialStoreProtocol
    var config: OAuthRefreshTokenConfig?
    
    init(credentialStore: CredentialStoreProtocol) {
        self.credentialStore = credentialStore
    }
    
    func intercept<T>(task: URLAsyncTask<T>, session: ContentProvider) -> URLAsyncTask<T> {
        return task
    }
    
    func intercept<T>(task: URLAsyncTask<T>, session: ContentProvider, networkService: AsyncTaskService, completion: @escaping (URLAsyncTask<T>) -> Void) {
        
        guard let config = self.config,
              let tokenURL = session.resolve(url: config.tokenUrl + "/token"),
              task.input.url != tokenURL, // don't intercept already running refresh task
              let credential = try? self.credentialStore.retrieveCredential(.token, isRequired: false).get(),
              Date() >= credential.expirationDate,
              let refreshToken = try? self.credentialStore.retrieveCredential(.refreshToken, isRequired: false).get()
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

        let refreshTask = URLAsyncTask<OAuthRefreshTokenResponse>.build(
            url: tokenURL,
            method: .POST,
            body: paramsString.data(using: .utf8),
            session: session,
            headers: ["Content-Type": "application/x-www-form-urlencoded"],
            parser: { try OAuthRefreshTokenResponse.parse(data: $0) }
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
                        self?.tokenRefreshDidFail()
                        completion(task) // failed to update token, so complete with unmodified task
                    }
                })
            case .failure(let error):
                self?.tokenRefreshDidFail()
                completion(task) // failed to update token, so complete with unmodified task
            }
        }
    }
    
    private func tokenRefreshDidFail() {
        self.credentialStore.removeCredential(.token)
        self.credentialStore.removeCredential(.refreshToken)
    }
}
