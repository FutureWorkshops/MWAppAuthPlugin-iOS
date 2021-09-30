//
//  MWAppAuthStepViewController+AppAuth.swift
//  MWAppAuthPlugin
//
//  Created by Jonathan Flintham on 02/03/2021.
//

import UIKit
import MobileWorkflowCore
import AppAuth
import AuthenticationServices

extension MWAppAuthStepViewController {
    
    func performOAuth(config: OAuth2Config) {
        guard
            let oAuth2Url = self.appAuthStep.session.resolve(url: config.oAuth2Url)?.absoluteString,
            let authorizationEndpoint = URL(string: oAuth2Url.appending(OAuthPaths.authorization)),
            let tokenEndpoint = URL(string: oAuth2Url.appending(OAuthPaths.token)),
            let redirectURL = URL(string: config.oAuth2RedirectScheme + "://callback")
            else { return }
        
        self.showLoading()
        
        let configuration = OIDServiceConfiguration(
            authorizationEndpoint: authorizationEndpoint,
            tokenEndpoint: tokenEndpoint
        )
        
        let request = OIDAuthorizationRequest(
            configuration: configuration,
            clientId: config.oAuth2ClientId,
            clientSecret: (config.oAuth2ClientSecret?.isEmpty ?? true) ? nil : config.oAuth2ClientSecret,
            scopes: [config.oAuth2Scope],
            redirectURL: redirectURL,
            responseType: OIDResponseTypeCode,
            additionalParameters: nil
        )
        
        let authProvider = AuthProviderImplementation() { completion in
            let session = OIDAuthState.authState(byPresenting: request, presenting: self) { authState, error in
                if let authState = authState, let accessToken = authState.lastTokenResponse?.accessToken, let expirationDate = authState.lastTokenResponse?.accessTokenExpirationDate {
                    let token = Credential(
                        type: CredentialType.token.rawValue,
                        value: accessToken,
                        expirationDate: expirationDate
                    )
                    var refresh: Credential?
                    if let refreshToken = authState.lastTokenResponse?.refreshToken {
                        refresh = Credential(
                            type: CredentialType.refreshToken.rawValue,
                            value: refreshToken,
                            expirationDate: .distantFuture
                        )
                    }
                    completion(.success([token, refresh].compactMap({ $0 })))
                } else {
                    completion(.failure(error ?? CredentialError.unexpected))
                }
            }
            return AppAuthFlowResumer(session: session)
        }
        let authenticationTask = AuthenticationTask(input: authProvider)
        self.appAuthStep.services.perform(task: authenticationTask, session: self.appAuthStep.session) { [weak self] (response) in
            DispatchQueue.main.async {
                self?.hideLoading()
                switch response {
                case .success:
                    self?.goForward()
                case .failure(let error):
                    if let authError = (error as NSError).userInfo[NSUnderlyingErrorKey] as? ASWebAuthenticationSessionError, authError.code == .canceledLogin {
                        // if cancel, do nothing
                    } else {
                        self?.show(error)
                    }
                }
            }
        }
    }
}

// MARK: - Authorization Controller Presentation

extension MWAppAuthStepViewController: ASAuthorizationControllerPresentationContextProviding {
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windows = self.view.window else {
            preconditionFailure()
        }
        
        return windows
    }
}

class AppAuthFlowResumer: AuthFlowResumer {
    
    private var session: OIDExternalUserAgentSession?
    
    init(session: OIDExternalUserAgentSession) {
        self.session = session
    }
    
    func resumeAuth(with url: URL) -> Bool {
        return self.session?.resumeExternalUserAgentFlow(with: url) ?? false
    }
}
