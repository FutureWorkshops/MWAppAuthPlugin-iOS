//
//  MWAppAuthStepViewController+AppAuth.swift
//  MWAppAuthPlugin
//
//  Created by Jonathan Flintham on 02/03/2021.
//

import UIKit
import MobileWorkflowCore
import AuthenticationServices

struct WebAuthenticationRequest: URLQuery {
    private enum Constants {
        static let redirectPath = "://callback"
    }
    let clientId: String
    let scope: String
    let redirectUri: String
    let responseType: String = "code"
    
    init(config: OAuth2Config) {
        self.clientId = config.oAuth2ClientId
        self.scope = config.oAuth2Scope
        self.redirectUri = config.oAuth2RedirectScheme.appending(Constants.redirectPath)
    }
}

struct OAuthAccessTokenResponse: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case scope = "scope"
        case refreshToken = "refresh_token"
    }
    
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let scope: String
    let refreshToken: String?
}

extension MWAppAuthStepViewController {
    
    func performOAuth(config: OAuth2Config) {
        let webAuthorizationRequest = WebAuthenticationRequest(config: config)
        guard
            let oAuth2Url = self.appAuthStep.session.resolve(url: config.oAuth2Url)?.absoluteString,
            let authorizationURL = webAuthorizationRequest.queryURL(for: oAuth2Url.appending(OAuthPaths.authorization)),
            let tokenURL = URL(string: oAuth2Url.appending(OAuthPaths.token))
        else { return }
        
        self.showLoading()
        
        let authProvider = AuthProviderImplementation() { [weak self] completion in
            guard let strongSelf = self else {
                completion(.failure(URLError(.cancelled)))
                return nil
            }
            
            let session = ASWebAuthenticationSession(
                url: authorizationURL,
                callbackURLScheme: config.oAuth2RedirectScheme,
                completionHandler: { [weak self] callbackURL, error in
                    guard let session = self?.appAuthStep.session,
                          let services = self?.appAuthStep.services
                    else { return }
                    
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    
                    guard let callbackURL = callbackURL,
                          let queryItems = NSURLComponents(string: callbackURL.absoluteString)?.queryItems,
                          let code = queryItems.filter({$0.name == "code"}).first?.value
                    else {
                        completion(.failure(URLError(.badServerResponse)))
                        return
                    }
                    
                    var params: [String: String] = [
                        "grant_type": "authorization_code",
                        "client_id": config.oAuth2ClientId,
                        "redirect_uri": config.oAuth2RedirectScheme + "://callback",
                        "code": code
                    ]
                    if let secret = config.oAuth2ClientSecret {
                        params["client_secret"] = secret
                    }
                    let paramsString = params.map({ "\($0.key)=\($0.value)" }).joined(separator: "&") // url encoding
                    
                    let tokenTask = URLAsyncTask<OAuthAccessTokenResponse>.build(
                        url: tokenURL,
                        method: .POST,
                        body: paramsString.data(using: .utf8),
                        session: session,
                        headers: ["Content-Type": "application/x-www-form-urlencoded"],
                        parser: { try OAuthAccessTokenResponse.parse(data: $0) }
                    )
                    
                    services.perform(task: tokenTask, session: session) { [weak self] result in
                        switch result {
                        case .success(let response):
                            let token = Credential(
                                type: CredentialType.token.rawValue,
                                value: response.accessToken,
                                expirationDate: Date().addingTimeInterval(TimeInterval(response.expiresIn))
                            )
                            var refresh: Credential?
                            if let refreshToken = response.refreshToken {
                                refresh = Credential(
                                    type: CredentialType.refreshToken.rawValue,
                                    value: refreshToken,
                                    expirationDate: .distantFuture
                                )
                            }
                            completion(.success([token, refresh].compactMap({ $0 })))
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                }
            )
            
            session.prefersEphemeralWebBrowserSession = true // TODO: should be specified in the app config
            session.presentationContextProvider = strongSelf
            
            return AppAuthFlowResumer(session: session)
        }
        let authenticationTask = AuthenticationTask(input: authProvider)
        self.appAuthStep.services.perform(task: authenticationTask, session: self.appAuthStep.session) { [weak self] response in
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

extension MWAppAuthStepViewController: ASWebAuthenticationPresentationContextProviding {
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let window = self.view.window else { preconditionFailure() }
        return window
    }
}

extension MWAppAuthStepViewController: ASAuthorizationControllerPresentationContextProviding {
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let window = self.view.window else { preconditionFailure() }
        return window
    }
}

class AppAuthFlowResumer: AuthFlowResumer {
    
    private let session: ASWebAuthenticationSession
    
    init(session: ASWebAuthenticationSession) {
        self.session = session
        self.session.start()
    }
    
    func resumeAuth(with url: URL) -> Bool {
        // ASWebAuthenticationSession doesn't need to be manually resumed
        return true
    }
}
