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

fileprivate class ROPCFormTaskViewController: MWWorkflowViewController {
    let config: OAuthROPCConfig
    
    init(workflow: Workflow, config: OAuthROPCConfig) {
        self.config = config
        super.init(workflow: workflow)
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
        
        let workflow = MWWorkflow(identifier: kFormTaskIdentifier, steps: [step], id: kFormTaskIdentifier, name: nil, title: nil, systemImageName: nil, session: self.appAuthStep.session.copyForChild())
        let vc = ROPCFormTaskViewController(workflow: workflow, config: config)
        vc.isDiscardable = true
        vc.workflowDelegate = self
        
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
            params["client_secret"] = secret
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
                let token = Credential(
                    type: CredentialType.token.rawValue,
                    value: response.accessToken,
                    expirationDate: Date().addingTimeInterval(TimeInterval(response.expiresIn))
                )
                let refresh = Credential(
                    type: CredentialType.refreshToken.rawValue,
                    value: response.refreshToken,
                    expirationDate: .distantFuture
                )
                self?.appAuthStep.services.credentialStore.updateCredentials([token, refresh], completion: { [weak self] result in
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

extension MWAppAuthStepViewController: WorkflowViewControllerDelegate {
    
    func workflowViewControllerCanBeDismissed(_ workflowViewController: WorkflowViewController) -> Bool {
        return true
    }
    
    func workflowViewController(_ workflowViewController: WorkflowViewController, didFinishWith reason: WorkflowFinishReason) {
        workflowViewController.presentingViewController?.dismiss(animated: true) { [weak self] in
            #warning("This data extraction from session needs to be tested")
            guard reason == .completed,
                  let config = (workflowViewController as? ROPCFormTaskViewController)?.config,
                  let username = workflowViewController.workflow.session.fetchValue(resource: "\(kUsernameItemIdentifier).answer") as? String,
                  let password = workflowViewController.workflow.session.fetchValue(resource: "\(kPasswordItemIdentifier).answer") as? String
            else { return }
            self?.performOAuthROPCRequest(config: config, username: username, password: password)
        }
    }
    
    func workflowViewController(_ workflowViewController: WorkflowViewController, stepViewControllerWillAppear stepViewController: StepViewController) {
        guard let stepViewController = stepViewController as? ORKStepViewController else { preconditionFailure() }
        stepViewController.continueButtonItem?.title = L10n.AppAuth.loginTitle
    }
    
    func workflowViewController(_ workflowViewController: WorkflowViewController, stepViewControllerWillDisappear stepViewController: StepViewController) {
        // nothing
    }
}
