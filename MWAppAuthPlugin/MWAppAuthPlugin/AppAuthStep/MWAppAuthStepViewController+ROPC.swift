//
//  MWAppAuthStepViewController+ROPC.swift
//  MWAppAuthPlugin
//
//  Created by Jonathan Flintham on 02/03/2021.
//

import UIKit
import MobileWorkflowCore

extension MWAppAuthStepViewController {
    
    func performOAuthROPC(config: OAuthROPCConfig) {
        guard
            let tokenUrlString = config.oAuth2TokenUrl,
            let tokenURL = self.appAuthStep.session.resolve(url: tokenUrlString)
        else { return }
        
        var params: [String: String] = [
            "grant_type": "password",
            "client_id": config.oAuth2ClientId,
            "username": "***",
            "password": "***"
        ]
        if let secret = config.oAuth2ClientSecret {
            params["client_secret"] = config.oAuth2ClientSecret
        }
        
        let paramsString = params.map({ "\($0.key)=\($0.value)" }).joined(separator: "&") // url encoding
        
        let task = URLAsyncTask<ROPCResponse>.build(
            url: tokenURL,
            method: .POST,
            body: paramsString.data(using: .utf8),
            session: self.appAuthStep.session,
            headers: ["Content-Type": "application/x-www-form-urlencoded"],
            parser: { try ROPCResponse.parse(data: $0) }
        )
        
        self.ropcNetworkService.perform(task: task, session: self.appAuthStep.session, respondOn: DispatchQueue.main) { [weak self] result in
            switch result {
            case .success(let response):
                let credential = Credential(
                    type: CredentialType.token.rawValue,
                    value: response.accessToken,
                    expirationDate: Date().addingTimeInterval(TimeInterval(response.expiresIn))
                )
                self?.appAuthStep.services.credentialStore.updateCredential(credential, completion: { result in
                    switch result {
                    case .success:
                        self?.goForward()
                    case .failure(let error):
                        self?.show(error)
                    }
                })
            case .failure(let error):
                self?.show(error)
            }
        }
    }
}

struct ROPCResponse: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case scope = "scope"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
    
    let accessToken: String
    let refreshToken: String
    let scope: String
    let tokenType: String
    let expiresIn: Int
}
