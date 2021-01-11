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

class MWAppAuthStepViewController: ORKTableStepViewController, WorkflowPresentationDelegator {
    
    weak var workflowPresentationDelegate: WorkflowPresentationDelegate?
    
    //MARK: - Support variables
    var appAuthStep: MWAppAuthStep! {
        return self.step as? MWAppAuthStep
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.hideNavigationFooterView()
        self.tableView?.contentInsetAdjustmentBehavior = .automatic // ResearchKit sets this to .never
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        super.tableView(tableView, willDisplay: cell, forRowAt: indexPath)
        if let cell = cell as? MobileWorkflowButtonTableViewCell {
            cell.delegate = self
        }
    }
    
    private func performOAuth(config: OAuth2Config) {
        guard
            let authorizationEndpoint = URL(string: config.oAuth2Url.appending(OAuthPaths.authorization)),
            let tokenEndpoint = URL(string: config.oAuth2Url.appending(OAuthPaths.token)),
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
        self.appAuthStep?.services.perform(task: authenticationTask) { [weak self] (response) in
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
    
    // MARK: Loading
    
    public func showLoading() {
        self.tableView?.isUserInteractionEnabled = false
        self.tableView?.backgroundView = LoadingStateView(frame: .zero)
    }

    public func hideLoading() {
        self.tableView?.isUserInteractionEnabled = true
        self.tableView?.backgroundView = nil
    }
}

extension MWAppAuthStepViewController: MobileWorkflowButtonTableViewCellDelegate {
    
    func buttonCell(_ cell: MobileWorkflowButtonTableViewCell, didTapButton button: UIButton) {
        guard let indexPath = self.tableView?.indexPath(for: cell),
            let item = self.appAuthStep.objectForRow(at: indexPath) as? AuthItem,
            let representation = try? item.respresentation()
            else { return }
        
        switch representation {
        case .oauth(_, let config):
            self.performOAuth(config: config)
        case .twitter(_):
            break // TODO: perform twitter login
        case .modalWorkflowId(_,  let modalWorkflowId):
            self.workflowPresentationDelegate?.presentWorkflowWithId(modalWorkflowId, isDiscardable: true, animated: true, onDismiss: { reason in
                if reason == .completed {
                    self.goForward()
                }
            })
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
