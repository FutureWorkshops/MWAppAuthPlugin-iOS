//
//  MWAppAuthStepViewController+Apple.swift
//  MWAppAuthPlugin
//
//  Created by Jonathan Flintham on 02/03/2021.
//

import UIKit
import MobileWorkflowCore
import AuthenticationServices

// MARK: - Sign in with Apple

extension MWAppAuthStepViewController: SignInWithAppleButtonTableViewCellDelegate {
    func appleCell(_ cell: SignInWithAppleButtonTableViewCell, didTapButton button: UIButton) {
        guard let indexPath = self.tableView.indexPath(for: cell), let item = self.appAuthStep.items[safe: indexPath.row] as? AuthStepItem, let representation = try? item.respresentation() else { return }
        
        switch representation {
        case .apple:
            self.appleAccessTokenURL = item.appleAccessTokenURL
            self.handleDidTapSignInWithApple(needsFullName: item.appleFullNameScope ?? false, needsEmail: item.appleEmailScope ?? false)
        default:
            break
        }
    }
}

extension MWAppAuthStepViewController {
    
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
        
        guard let urlString = self.appleAccessTokenURL,
              let url = self.appAuthStep.session.resolve(url: urlString)
        else {
            return
        }
        
        let data = try? JSONEncoder().encode(appleCredential)
        
        let parser: (Data) throws -> Credential = { data in
            return try JSONDecoder().decode(Credential.self, from: data)
        }
        
        let authTask = URLAsyncTask<Credential>.build(url: url, method: .POST, body: data, session: self.appAuthStep.session, parser: parser)
        
        self.appAuthStep.services.perform(task: authTask, session: self.appAuthStep.session) { [weak self] (response) in
            DispatchQueue.main.async {
                self?.hideLoading()
                switch response {
                case .success(let credential):
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
    
    func makeName(fullName: PersonNameComponents?) -> String {
        guard let fullName = fullName else {
            return ""
        }
        
        var nameComponents = [String]()
        if let givenName = fullName.givenName {
            nameComponents.append(givenName)
        }
        if let familyName = fullName.familyName {
            nameComponents.append(familyName)
        }
        
        if nameComponents.isEmpty {
            return self.appleUsername ?? ""
        } else {
            let name = nameComponents.joined(separator: " ")
            self.appleUsername = name
            
            return name
        }
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
            
            // Name is only provided in the first response of an Auth request. Save it in case multiple attempts are required
            let name = self.makeName(fullName: appleIDCredential.fullName)
            
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
