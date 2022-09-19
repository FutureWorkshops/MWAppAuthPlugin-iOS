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

class MWAppAuthStepViewController: MWTableStepViewController<MWAppAuthStep>, PresentationDelegator {
    
    weak var presentationDelegate: PresentationDelegate?
    
    //MARK: - Support variables
    var appAuthStep: MWAppAuthStep {
        return self.mwStep as! MWAppAuthStep
    }
    
    private var ongoingImageLoads: [IndexPath: Task<(), Never>] = [:]
    
    var appleAccessTokenURL: String?
    var appleUsername: String?
    
    private(set) lazy var ropcNetworkService: NetworkAsyncTaskService = {
        NetworkAsyncTaskService(urlSession: .shared)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.allowsSelection = false
    }
    
    // MARK: UITableView
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return self.appAuthStep.imageURL == nil ? 0 : 1
        case 1: return (self.appAuthStep.text?.isEmpty ?? true) ? 0 : 1
        case 2: return self.appAuthStep.items.count
        default: return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        super.tableView(tableView, willDisplay: cell, forRowAt: indexPath)
        if let cell = cell as? MWButtonTableViewCell {
            cell.delegate = self
        }
        else if let cell = cell as? SignInWithAppleButtonTableViewCell {
            cell.delegate = self
        }
        if let cell = cell as? MWImageTableViewCell {
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
            self.update(image: nil, of: cell, animated: false)
            return
        }
        let cancellable = Task {
            let result = await self.appAuthStep.services.imageLoadingService.load(image: imageURL, session: self.appAuthStep.session)
            self.update(image: result.image, of: cell, animated: result.wasLoadedRemotely)
            self.ongoingImageLoads.removeValue(forKey: indexPath)
        }
        self.ongoingImageLoads[indexPath] = cancellable // will be nil if image was returned from cache
    }
    
    @MainActor
    private func update(image: UIImage?, of cell: UITableViewCell, animated: Bool) {
        guard let cell = cell as? MWImageTableViewCell else { return }
        cell.configure(backgroundImage: image, animated: animated)
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
        self.tableView.isUserInteractionEnabled = false
    }

    public func hideLoading() {
        self.tableView.isUserInteractionEnabled = true
    }
}

extension MWAppAuthStepViewController: MWButtonTableViewCellDelegate {
    
    func buttonCell(_ cell: MWButtonTableViewCell, didTapButton button: UIButton) {
        guard let indexPath = self.tableView.indexPath(for: cell),
              let item = self.appAuthStep.items[safe: indexPath.row],
              let representation = try? item.respresentation()
        else { return }
        
        switch representation {
        case .oauth(_, let config):
            self.performOAuth(config: config)
        case .oauthRopc(let buttonTitle, let config):
            self.performOAuthROPC(title: buttonTitle, config: config)
        case .twitter(_):
            break // TODO: perform twitter login
        case .modalLink(_,  let linkId):
            self.presentationDelegate?.presentStepForLinkId(linkId, isDiscardable: true, animated: true, willDismiss: { [weak self] reason in
                // need to do this before dismissal to avoid seeing the login options briefly
                if reason == .completed,
                   let _ = try? self?.appAuthStep.services.credentialStore.retrieveCredential(.token, isRequired: false).get() {
                    self?.goForward() // i.e. dismiss login options
                }
            }, didDismiss: nil)
        case .apple:
            break
        }
    }
}
