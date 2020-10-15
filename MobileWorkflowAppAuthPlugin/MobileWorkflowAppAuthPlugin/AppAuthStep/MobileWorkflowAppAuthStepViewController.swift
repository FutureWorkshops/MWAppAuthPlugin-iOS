//
//  MobileWorkflowAppAuthStepViewController.swift
//  MobileWorkflow
//
//  Created by Igor Ferreira on 19/05/2020.
//  Copyright © 2020 Future Workshops. All rights reserved.
//

import Foundation
import ResearchKit
import MobileWorkflowCore
import AppAuth

enum Constants {
    static let redirectScheme = "mww"
}

enum OAuthPaths {
    static let authorization = "/authorize"
    static let token = "/token"
}

class MobileWorkflowAppAuthStepViewController: MobileWorkflowButtonViewController {
    
    //MARK: - Support variables
    var appAuthStep: MobileWorkflowAppAuthStep! {
        return self.step as? MobileWorkflowAppAuthStep
    }
    
    var networkManager: NetworkManager {
        return self.appAuthStep.networkManager
    }
    
    private var loginButton: UIButton!
    private var buttonsRow: UIView!
    private var titleLabel: ORKTitleLabel!
    private var bodyLabel: ORKBodyLabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // configureWithTitle
    }

    @objc func login() {
        guard
            let step = self.appAuthStep,
            let authorizationEndpoint = URL(string: step.url.appending(OAuthPaths.authorization)),
            let tokenEndpoint = URL(string: step.url.appending(OAuthPaths.token)),
            let redirectURL = URL(string: Constants.redirectScheme + "://callback")
            else { return }
        
        let configuration = OIDServiceConfiguration(
            authorizationEndpoint: authorizationEndpoint,
            tokenEndpoint: tokenEndpoint
        )
        
        let request = OIDAuthorizationRequest(
            configuration: configuration,
            clientId: step.clientId,
            clientSecret: (step.clientSecret?.isEmpty ?? true) ? nil : step.clientSecret,
            scopes: [step.scope],
            redirectURL: redirectURL,
            responseType: OIDResponseTypeCode,
            additionalParameters: nil
        )
        
        let authProvider = AuthProviderImplementation() { completion in
            let session = OIDAuthState.authState(byPresenting: request, presenting: self) { authState, error in
                if let authState = authState, let accessToken = authState.lastTokenResponse?.accessToken, let  expirationDate = authState.lastTokenResponse?.accessTokenExpirationDate {
                    let token = Credential(
                        type: CredentialType.token.rawValue,
                        value: accessToken,
                        expirationDate: expirationDate
                    )
                    completion(.success(token))
                } else {
                    completion(.failure(error ?? CredentialError.unexpected))
                }
            }
            return AppAuthFlowResumer(session: session)
        }
        
        step.networkManager.authenticateWithProvider(authProvider) { [weak self] response in
            switch response {
            case .success:
                self?.goForward()
            case .failure(let error):
                self?.show(error)
            }
        }
    }
}

class AppAuthFlowResumer: AuthFlowResumer {
    
    private weak var session: OIDExternalUserAgentSession?
    
    init(session: OIDExternalUserAgentSession) {
        self.session = session
    }
    
    func resumeAuth(with url: URL) -> Bool {
        return self.session?.resumeExternalUserAgentFlow(with: url) ?? false
    }
}
