//
//  MWAppAuthStepViewController+ROPC.swift
//  MWAppAuthPlugin
//
//  Created by Jonathan Flintham on 02/03/2021.
//

import UIKit
import MobileWorkflowCore

fileprivate let kFormStepIdentifier = "ROPC_FORM_STEP"

fileprivate class ROPCFormTaskViewController: StepNavigationViewController {
    let config: OAuthROPCConfig
    
    init(
        config: OAuthROPCConfig,
        stepBuilders: [StepBuilder],
        initialStep: Step,
        session: Session,
        theme: Theme = .current,
        services: StepServices? = nil,
        outputDirectory: URL?,
        presentation: Presentation?
    ) {
        self.config = config
        super.init(
            stepBuilders: stepBuilders,
            initialStep: initialStep,
            session: session,
            theme: theme,
            services: services,
            outputDirectory: outputDirectory,
            presentation: presentation
        )
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension MWAppAuthStepViewController {
    
    func performOAuthROPC(title: String, config: OAuthROPCConfig) {
        
        let childSession = self.appAuthStep.session.copyForChild()
        
        let step = ROPCStep(identifier: kFormStepIdentifier,
                            title: title,
                            text: config.text,
                            imageURL: config.imageURL,
                            services: self.appAuthStep.services,
                            session: childSession,
                            submitBlock: { [weak self] (loginViewController, credentials) in
            self?.performOAuthROPCRequest(config: config,
                                          username: credentials.username,
                                          password: credentials.password,
                                          loginViewController: loginViewController)
        })
        
        let vc = ROPCFormTaskViewController(
            config: config,
            stepBuilders: [],
            initialStep: step,
            session: childSession,
            theme: self.mwStep.theme,
            services: self.appAuthStep.services,
            outputDirectory: self.outputDirectory,
            presentation: .init(
                context: .init(
                    dismissRule: .noRestriction,
                    willDismiss: nil,
                    didDismiss: { [weak self] reason in
                        if reason == .completed {
                            self?.goForward()
                        }
                    }
                ),
                dismiss: { [weak self] reason, context in
                    context.willDismiss?(reason)
                    self?.dismiss(animated: true) {
                        context.didDismiss?(reason)
                    }
                }
            )
        )

        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        vc.modalPresentationStyle = isPad ? .formSheet : .fullScreen
        vc.modalTransitionStyle = .coverVertical
        vc.isModalInPresentation = true
        self.present(vc, animated: true, completion: nil)
    }
    
    private func performOAuthROPCRequest(config: OAuthROPCConfig, username: String, password: String, loginViewController: MWROPCLoginViewController) {
        guard let tokenURL = self.appAuthStep.session.resolve(url: config.oAuth2TokenUrl) else { return }
        
        var params: [String: String] = [
            "grant_type": "password",
            "client_id": config.oAuth2ClientId,
            "username": username,
            "password": password
        ]
        if let secret = config.oAuth2ClientSecret {
            params["client_secret"] = secret
        }
        if let scope = config.oAuth2Scope {
            params["scope"] = config.oAuth2Scope
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
        
        loginViewController.showLoading()
        self.ropcNetworkService.perform(task: task, session: self.appAuthStep.session, respondOn: .main) { [weak self] result in
            loginViewController.hideLoading()
            switch result {
            case .success(let response):
                
                let token = Credential(
                    type: CredentialType.token.rawValue,
                    value: response.accessToken,
                    expirationDate: Date().addingTimeInterval(TimeInterval(response.expiresIn))
                )
                
                var tokens : [Credential] = [token]
                
                if let refreshToken = response.refreshToken, refreshToken.isEmpty == false {
                    let refresh = Credential(
                        type: CredentialType.refreshToken.rawValue,
                        value: refreshToken,
                        expirationDate: .distantFuture
                    )
                    tokens.append(refresh)
                }
                
                self?.handle(tokens: tokens, loginViewController: loginViewController)
            case .failure(let error):
                
                if error.isAuthenticationError {
                    let alert = UIAlertController(title: L10n.AppAuth.unauthorisedAlertTitle, message: L10n.AppAuth.unauthorisedAlertMessage, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: L10n.AppAuth.unauthorisedAlertButton, style: .default, handler: nil))
                    loginViewController.present(alert, animated: true, completion: nil)
                } else{
                    loginViewController.show(error)
                }
                
            }
        }
    }
    
    func handle(tokens: [Credential], loginViewController: MWROPCLoginViewController) {
        let result = self.appAuthStep.services.credentialStore.updateCredentials(tokens)
        switch result {
        case .success:
            loginViewController.goForward()
        case .failure(let error):
            loginViewController.show(error)
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
    let refreshToken: String?
    let scope: String?
    let tokenType: String
    let expiresIn: Int
}
