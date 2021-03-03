//
//  MWAppAuthStepViewController+ROPC.swift
//  MWAppAuthPlugin
//
//  Created by Jonathan Flintham on 02/03/2021.
//

import UIKit
import MobileWorkflowCore

fileprivate let kUsernameItemIdentifier = "ROPC_USERNAME_FORM_ITEM"
fileprivate let kPasswordItemIdentifier = "ROPC_PASSWORD_FORM_ITEM"
fileprivate let kFormStepIdentifier = "ROPC_FORM_STEP"
fileprivate let kFormTaskIdentifier = "ROPC_FORM_TASK"

fileprivate class ROPCFormTaskViewController: ORKTaskViewController {
    let config: OAuthROPCConfig
    
    init(task: ORKTask, config: OAuthROPCConfig) {
        self.config = config
        super.init(task: task, taskRun: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension MWAppAuthStepViewController {
    
    func performOAuthROPC(title: String, config: OAuthROPCConfig) {
        
        let headerTitleItem = ORKFormItem(sectionTitle: L10n.AppAuth.loginDetailsTitle)
        
        let usernameAnswerFormat = ORKTextAnswerFormat()
        usernameAnswerFormat.multipleLines = false
        usernameAnswerFormat.autocapitalizationType = .none
        usernameAnswerFormat.autocorrectionType = .no
        usernameAnswerFormat.textContentType = .username
        let usernameFormItem = ORKFormItem(identifier: kUsernameItemIdentifier, text: L10n.AppAuth.usernameFieldTitle, answerFormat: usernameAnswerFormat)
        usernameFormItem.isOptional = false
        
        let passwordAnswerFormat = ORKTextAnswerFormat()
        passwordAnswerFormat.isSecureTextEntry = true
        passwordAnswerFormat.textContentType = .password
        passwordAnswerFormat.multipleLines = false
        let passwordFormItem = ORKFormItem(identifier: kPasswordItemIdentifier, text: L10n.AppAuth.passwordFieldTitle, answerFormat: passwordAnswerFormat)
        passwordFormItem.isOptional = false
        
        let step = ORKFormStep(identifier: kFormStepIdentifier, title: title.capitalized, text: nil)
        step.formItems = [headerTitleItem, usernameFormItem, passwordFormItem]
        step.isOptional = false
        
        let task = ORKNavigableOrderedTask(identifier: kFormTaskIdentifier, steps: [step])
        let vc = ROPCFormTaskViewController(task: task, config: config)
        vc.discardable = true
        vc.delegate = self
        
        self.present(vc, animated: true, completion: nil)
    }
    
    private func performOAuthROPCRequest(config: OAuthROPCConfig, username: String, password: String) {
        guard let tokenURL = self.appAuthStep.session.resolve(url: config.oAuth2TokenUrl) else { return }
        
        var params: [String: String] = [
            "grant_type": "password",
            "client_id": config.oAuth2ClientId,
            "username": username,
            "password": password
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
        
        self.showLoading()
        self.ropcNetworkService.perform(task: task, session: self.appAuthStep.session, respondOn: .main) { [weak self] result in
            self?.hideLoading()
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

extension MWAppAuthStepViewController: ORKTaskViewControllerDelegate {
    
    func taskViewController(_ taskViewController: ORKTaskViewController, stepViewControllerWillAppear stepViewController: ORKStepViewController) {
        stepViewController.continueButtonTitle = L10n.AppAuth.loginTitle
    }
    
    func taskViewController(_ taskViewController: ORKTaskViewController, didFinishWith reason: ORKTaskViewControllerFinishReason, error: Error?) {
        taskViewController.presentingViewController?.dismiss(animated: true) { [weak self] in
            guard reason == .completed,
                  let config = (taskViewController as? ROPCFormTaskViewController)?.config,
                  let stepResult = taskViewController.result.stepResult(forStepIdentifier: kFormStepIdentifier),
                  let usernameResult = stepResult.result(forIdentifier: kUsernameItemIdentifier) as? ORKTextQuestionResult,
                  let username = usernameResult.answer as? String,
                  let passwordResult = stepResult.result(forIdentifier: kPasswordItemIdentifier) as? ORKTextQuestionResult,
                  let password = passwordResult.answer as? String
            else { return }
            self?.performOAuthROPCRequest(config: config, username: username, password: password)
        }
    }
}
