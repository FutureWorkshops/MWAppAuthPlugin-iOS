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
import Combine
import AuthenticationServices

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
    
    private var ongoingImageLoads: [IndexPath: AnyCancellable] = [:]
    private var appleAccessTokenURL: String?
    
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
        else if let cell = cell as? SignInWithAppleButtonTableViewCell {
            cell.delegate = self
        }
        self.loadImage(for: cell, at: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // super.tableView(tableView, didEndDisplaying: cell, forRowAt: indexPath) // not implemented in ORKTableStepViewController and respondsToSelector returns true...
        self.cancelImageLoad(for: cell, at: indexPath)
    }
    
    // MARK: Loading
    
    private func loadImage(for cell: UITableViewCell, at indexPath: IndexPath) {
        guard let imageURL = self.appAuthStep.imageURL,
              let resolvedURL = self.appAuthStep.session.resolve(url: imageURL)?.absoluteString else {
            self.update(image: nil, of: cell)
            return
        }
        let cancellable = self.appAuthStep.services.imageLoadingService.asyncLoad(image: resolvedURL) { [weak self] image in
            self?.update(image: image, of: cell)
            self?.ongoingImageLoads.removeValue(forKey: indexPath)
        }
        self.ongoingImageLoads[indexPath] = cancellable
    }
    
    private func update(image: UIImage?, of cell: UITableViewCell) {
        guard let cell = cell as? MobileWorkflowImageTableViewCell else { return }
        cell.backgroundImage = image
        cell.setNeedsLayout()
    }
    
    private func cancelImageLoad(for cell: UITableViewCell, at indexPath: IndexPath) {
        if let imageLoad = self.ongoingImageLoads[indexPath] {
            imageLoad.cancel()
            self.ongoingImageLoads.removeValue(forKey: indexPath)
        }
    }
    
    // OAuth2
    
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
        self.appAuthStep?.services.perform(task: authenticationTask, session: self.appAuthStep.session) { [weak self] (response) in
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
        self.tableView?.backgroundView = StateView(frame: .zero)
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
        case .apple:
            break
        }
    }
}

// MARK: - Sign in with Apple

extension MWAppAuthStepViewController: SignInWithAppleButtonTableViewCellDelegate {
    func appleCell(_ cell: SignInWithAppleButtonTableViewCell, didTapButton button: UIButton) {
        guard let indexPath = self.tableView?.indexPath(for: cell), let item = self.appAuthStep.objectForRow(at: indexPath) as? AuthItem, let representation = try? item.respresentation() else { return }
        
        switch representation {
        case .apple:
            self.appleAccessTokenURL = item.appleAccessTokenURL
            self.handleDidTapSignInWithApple(needsFullName: item.appleFullNameScope ?? false, needsEmail: item.appleEmailScope ?? false)
        default:
            break
        }
    }
}

private extension MWAppAuthStepViewController {
    
    func handleDidTapSignInWithApple(needsFullName: Bool, needsEmail: Bool) {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = []
        
        if needsFullName {
            request.requestedScopes?.append(.fullName)
        }
        
        if needsEmail {
            request.requestedScopes?.append(.email)
        }
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        
        authorizationController.performRequests()
    }
    
    func performSignInWithApple(userId: String, name: String, identityToken: String) {
        
        let appleCredential = AppleIDCredential(userId: userId, name: name, identityToken: identityToken)
        
        guard let urlString = self.appleAccessTokenURL, let url = URL(string: urlString) else {
            return
        }
        
        let data = try? JSONEncoder().encode(appleCredential)
        
        let parser: (Data) throws -> Credential = { data in
            return try JSONDecoder().decode(Credential.self, from: data)
        }
        
        let authTask = URLAsyncTask<Credential>.build(url: url, method: .POST, body: data, session: self.appAuthStep.session, parser: parser)
        
        self.appAuthStep?.services.perform(task: authTask, session: self.appAuthStep.session) { [weak self] (response) in
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
    
    func makeName(fullName: PersonNameComponents?) -> String? {
        guard let fullName = fullName else {
            return nil
        }
        
        var nameComponents = [String]()
        if let givenName = fullName.givenName {
            nameComponents.append(givenName)
        }
        if let familyName = fullName.familyName {
            nameComponents.append(familyName)
        }
        
        return nameComponents.joined(separator: " ")
    }
}

struct AppleIDCredential: Codable {
    let userId: String
    let name: String
    let identityToken: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_identity"
        case name = "name"
        case identityToken = "jwt"
    }
}

// MARK: - Authorization Controller Delegate

extension MWAppAuthStepViewController: ASAuthorizationControllerDelegate {
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        
        switch authorization.credential {
        case let appleIDCredential as ASAuthorizationAppleIDCredential:
            
            guard let identityToken = appleIDCredential.identityToken, let identityTokenString = String(data: identityToken, encoding: .utf8) else {
                self.showConfirmationAlert(title: L10n.AppleLogin.errorTitle, message: L10n.AppleLogin.errorMessage) { _ in }
                return
            }
            
            // Expiration date is not currently used, hence credential was set to `.distantFuture`. This should be reviewed in the future.
            let userIdCredential = Credential(
                type: CredentialType.appleIdCredentialUser.rawValue,
                value: appleIDCredential.user,
                expirationDate: .distantFuture
            )

            self.appAuthStep.services.credentialStore.updateCredential(userIdCredential) { [weak self] result in
                switch result {
                case .success:
                    let name = self?.makeName(fullName: appleIDCredential.fullName) ?? ""
                    
                    self?.performSignInWithApple(userId: appleIDCredential.user, name: name, identityToken: identityTokenString)
                    
                case .failure(let error):
                    self?.show(error)
                }
            }
            
        default:
            break
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        guard let authError = error as? ASAuthorizationError, authError.code != .canceled else {
            return
        }
        
        self.showConfirmationAlert(title: L10n.AppleLogin.errorTitle, message: L10n.AppleLogin.errorMessage) { _ in }
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
