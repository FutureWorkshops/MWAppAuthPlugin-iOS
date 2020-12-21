//
//  MWAppAuthStepViewController.swift
//  MobileWorkflow
//
//  Created by Igor Ferreira on 19/05/2020.
//  Copyright © 2020 Future Workshops. All rights reserved.
//

import Foundation
import MobileWorkflowCore
import AppAuth

enum OAuthPaths {
    static let authorization = "/authorize"
    static let token = "/token"
}

class MWAppAuthStepViewController: MobileWorkflowButtonViewController {
    
    //MARK: - Support variables
    var appAuthStep: MWAppAuthStep! {
        return self.step as? MWAppAuthStep
    }
    
    private var loginButton: UIButton!
    private var buttonsRow: UIView!
    private var titleLabel: ORKTitleLabel!
    private var bodyLabel: ORKBodyLabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.configureWithTitle(
            self.appAuthStep.title ?? "",
            body: self.appAuthStep.text ?? "",
            buttonTitle: self.appAuthStep.buttonTitle) { [weak self] in
            self?.showLoading()
            self?.login()
        }
    }

    @objc func login() {
        guard
            let step = self.appAuthStep,
            let authorizationEndpoint = URL(string: step.url.appending(OAuthPaths.authorization)),
            let tokenEndpoint = URL(string: step.url.appending(OAuthPaths.token)),
            let redirectURL = URL(string: step.redirectScheme + "://callback")
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
        let authenticationTask = AuthenticationTask(input: authProvider)
        step.services.perform(task: authenticationTask) { [weak self] (response) in
            DispatchQueue.main.async {
                self?.hideLoading()
                switch response {
                case .success:
                    self?.goForward()
                case .failure(let error):
                    self?.show(error)
                }
            }
        }
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
