//
//  MWAppAuthStepViewController.swift
//  MobileWorkflow
//
//  Created by Igor Ferreira on 19/05/2020.
//  Copyright © 2020 Future Workshops. All rights reserved.
//

import UIKit
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
    var appleAccessTokenURL: String?
    var appleUsername: String?
    
    private(set) lazy var ropcNetworkService: NetworkAsyncTaskService = {
        NetworkAsyncTaskService(urlSession: .shared)
    }()
    
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
        if let cell = cell as? MobileWorkflowImageTableViewCell {
            self.loadImage(for: cell, at: indexPath)
        }
    }
    
    override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // super.tableView(tableView, didEndDisplaying: cell, forRowAt: indexPath) // not implemented in ORKTableStepViewController and respondsToSelector returns true...
        self.cancelImageLoad(for: cell, at: indexPath)
    }
    
    // MARK: Loading
    
    private func loadImage(for cell: UITableViewCell, at indexPath: IndexPath) {
        guard let imageURL = self.appAuthStep.imageURL else {
            self.update(image: nil, of: cell)
            return
        }
        let cancellable = self.appAuthStep.services.imageLoadingService.asyncLoad(image: imageURL, session: self.appAuthStep.session) { [weak self] image in
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
    
    // MARK: Loading
    
    public func showLoading() {
        self.tableView?.isUserInteractionEnabled = false
    }

    public func hideLoading() {
        self.tableView?.isUserInteractionEnabled = true
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
        case .oauthRopc(let buttonTitle, let config):
            self.performOAuthROPC(title: buttonTitle, config: config)
        case .twitter(_):
            break // TODO: perform twitter login
        case .modalWorkflowId(_,  let modalWorkflowId):
            self.workflowPresentationDelegate?.presentWorkflowWithId(modalWorkflowId, isDiscardable: true, animated: true, onDismiss: { reason in
                if reason == .completed {
                    // do nothing, user will likely now need to login
                }
            })
        case .apple:
            break
        }
    }
}
