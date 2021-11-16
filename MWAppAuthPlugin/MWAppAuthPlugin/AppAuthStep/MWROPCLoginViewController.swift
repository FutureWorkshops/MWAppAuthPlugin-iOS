//
//  MWAppAuthLoginViewController.swift
//  MWAppAuthPlugin
//
//  Created by Julien Hebert on 18/10/2021.
//

import UIKit
import Combine
import MobileWorkflowCore

typealias Credentials = (username: String, password: String)
typealias SubmitBlock = (MWROPCLoginViewController, Credentials) -> Void

final class ROPCStep: MWStep {
    let imageURL: String?
    let services: StepServices
    let session: Session
    let submitBlock : SubmitBlock?
    
    init(identifier: String,
         title: String?,
         text: String?,
         imageURL: String?,
         services: StepServices,
         session: Session,
         submitBlock : SubmitBlock?) {
        self.imageURL = (imageURL?.isEmpty ?? true) ? nil : imageURL
        self.services = services
        self.session = session
        self.submitBlock = submitBlock
        super.init(identifier: identifier)
        self.title = title
        self.text = text
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func instantiateViewController() -> StepViewController {
        return MWROPCLoginViewController(ropcStep: self)
    }
    
}

final class MWROPCLoginViewController: MWContentStepViewController {
    
    public override var titleMode: StepViewControllerTitleMode { .largeTitle }
    private var scrollView: UIScrollView!
    private var contentStackView: UIStackView!
    private var imageView: UIImageView!
    private var loadingView: StateView!
    
    private lazy var bodyLabel: StepBodyLabel = {
        let bodyLabel = StepBodyLabel()
        bodyLabel.numberOfLines = 0
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.textColor = self.ropcStep.theme.primaryTextColor
        return bodyLabel
    }()

    private lazy var usernameField: MWROPCTextField = {
        let usernameField = MWROPCTextField(theme: self.ropcStep.theme)
        let emailConfig = MWROPCTextField.Config(title: L10n.AppAuth.usernameFieldTitle,
                                                 placeholder: L10n.AppAuth.required,
                                                 textContentType: .username)
        
        usernameField.configure(config: emailConfig)
        usernameField.delegate = self
        return usernameField
    }()
    
    private lazy var passwordField: MWROPCTextField = {
        let passwordField = MWROPCTextField(theme: self.ropcStep.theme)
        let passwordConfig = MWROPCTextField.Config(title: L10n.AppAuth.passwordFieldTitle,
                                                    placeholder: L10n.AppAuth.required,
                                                    isSecureTextEntry: true,
                                                    textContentType: .password)
        passwordField.configure(config: passwordConfig)
        passwordField.delegate = self
        return passwordField
    }()
    
    private lazy var separatorLine: UIView = {
        let separatorLine = UIView()
        separatorLine.backgroundColor = self.ropcStep.theme.groupedBackgroundColor
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        return separatorLine
    }()
    
    private lazy var loginButton: CustomButton = {
        let button = CustomButton(style: .primary, theme: self.ropcStep.theme)
        button.setTitle(L10n.AppAuth.loginTitle, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(self.submit), for: .touchUpInside)
        button.isEnabled = false
        return button
    }()
    
    private var imageLoad: AnyCancellable?
    
    private var imageViewHeightConstraint: NSLayoutConstraint?
    private var constraints: [NSLayoutConstraint] = [] {
        didSet {
            NSLayoutConstraint.deactivate(oldValue)
            NSLayoutConstraint.activate(self.constraints)
        }
    }
    
    private var ropcStep: ROPCStep {
        self.mwStep as! ROPCStep
    }
    
    public init(ropcStep: ROPCStep) {
        super.init(step: ropcStep)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = self.ropcStep.title
        self.setupUI()
        self.registerForKeyboardNotifications(self.scrollView, bottomMargin: 20.0)
        self.configureTapOutsideToDismiss()
    }
    
    private func setupUI() {
        self.hideNavigationFooterView()
        self.configureImageView(imageUrl: self.ropcStep.imageURL, image: nil)
        let body = self.ropcStep.session.resolve(value: self.ropcStep.text ?? "")
        self.bodyLabel.text = body.isEmpty ? L10n.AppAuth.loginDetailsTitle : body
        self.configureStackView()
        self.setupLoadingView()
        self.configureConstraints()
        self.configureStyle()
    }
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.configureStyle()
    }

    private func configureImageView(imageUrl: String?, image: UIImage?) {
        self.imageView = self.imageView ?? UIImageView()
        self.imageView.backgroundColor = self.ropcStep.theme.imagePlaceholderBackgroundColor
        self.imageView.clipsToBounds = true
        self.imageView.translatesAutoresizingMaskIntoConstraints = false
        
        if image == nil, let imageUrl = imageUrl {
            self.imageLoad = self.ropcStep.services.imageLoadingService.asyncLoad(image: imageUrl, session: self.ropcStep.session) { [weak self] in
                self?.updateImage($0, showPlaceholder: false)
                self?.imageLoad = nil
            }
            if self.imageView.image == nil {
                self.updateImage(nil, showPlaceholder: true)
            }
        } else {
            self.updateImage(image, showPlaceholder: false)
        }
    }
    
    private func updateImage(_ image: UIImage?, showPlaceholder: Bool) {
        if image == nil, showPlaceholder {
            let imageConfig = UIImage.SymbolConfiguration(textStyle: .largeTitle)
            let image = UIImage(systemName: "photo", withConfiguration: imageConfig)
            self.imageView.image = image
            self.imageView.contentMode = .center
        } else {
            self.imageView.image = image
            self.imageView.contentMode = .scaleAspectFill
        }
        let heightMultiplier: CGFloat = self.imageView.image == nil ? 0.0 : 0.3
        self.imageViewHeightConstraint = self.imageView.heightAnchor.constraint(equalTo: self.view.heightAnchor, multiplier: heightMultiplier)
        
        self.imageView.isHidden = self.imageView.image == nil
    }
    
    private func configureStackView() {
        
        let separatorLineStackView = UIStackView( arrangedSubviews: [self.separatorLine])
        separatorLineStackView.isLayoutMarginsRelativeArrangement = true
        separatorLineStackView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 0)
        
        let fieldsStackView = UIStackView(
            arrangedSubviews: [
                self.usernameField,
                separatorLineStackView,
                self.passwordField
            ]
        )
        fieldsStackView.backgroundColor = .white
        fieldsStackView.layer.cornerRadius = 8.0
        fieldsStackView.clipsToBounds = true
        fieldsStackView.translatesAutoresizingMaskIntoConstraints = false
        fieldsStackView.axis = .vertical
        fieldsStackView.alignment = .fill
        fieldsStackView.spacing = 0
        
        // container to ensure top alignment
        let containerStackView = UIStackView(
            arrangedSubviews: [self.bodyLabel, fieldsStackView, self.loginButton]
        )
        containerStackView.translatesAutoresizingMaskIntoConstraints = false
        containerStackView.axis = .vertical
        containerStackView.alignment = .fill
        containerStackView.spacing = 20
        containerStackView.isLayoutMarginsRelativeArrangement = true
        containerStackView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        
        let contentStackView = UIStackView(
            arrangedSubviews: [
                self.imageView,
                containerStackView
            ]
        )
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.alignment = .fill
        contentStackView.spacing = 16
        contentStackView.isLayoutMarginsRelativeArrangement = true
        contentStackView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 30, leading: 0, bottom: 30, trailing: 0)
        
        self.contentStackView?.removeFromSuperview()
        self.contentStackView = contentStackView
        
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStackView)
        
        self.scrollView?.removeFromSuperview()
        self.scrollView = scrollView
        self.contentView.addSubview(scrollView)
    }
    
    private func setupLoadingView() {
        self.loadingView = self.loadingView ?? StateView(frame: .zero)
        self.loadingView.configure(isLoading: true, theme: self.mwStep.theme)
        self.loadingView.translatesAutoresizingMaskIntoConstraints = false
        self.loadingView.backgroundColor = .clear
        self.contentView.addSubview(self.loadingView)
        self.hideLoading()
    }
    
    private func configureConstraints() {

        var constraints = [NSLayoutConstraint]()

        if let imageViewHeightConstraint = self.imageViewHeightConstraint {
            constraints.append(imageViewHeightConstraint)
        }
        
        let buttonHeightConstraint = self.loginButton.heightAnchor.constraint(equalToConstant: 50)
        buttonHeightConstraint.priority = .init(rawValue: 999)
        buttonHeightConstraint.isActive = true
        
        let lineHeightConstraint = self.separatorLine.heightAnchor.constraint(equalToConstant: 1)
        lineHeightConstraint.priority = .init(rawValue: 999)
        lineHeightConstraint.isActive = true
        
        let scrollViewConstraints = [
            self.scrollView.topAnchor.constraint(equalTo: self.contentView.topAnchor),
            self.scrollView.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor),
            self.scrollView.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor),
            self.scrollView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor)
        ]
        constraints.append(contentsOf: scrollViewConstraints)
        
        let contentStackViewConstraints = [
            self.contentStackView.topAnchor.constraint(equalTo: self.scrollView.topAnchor),
            self.contentStackView.leadingAnchor.constraint(equalTo: self.scrollView.leadingAnchor),
            self.contentStackView.trailingAnchor.constraint(equalTo: self.scrollView.trailingAnchor),
            self.contentStackView.bottomAnchor.constraint(equalTo: self.scrollView.bottomAnchor),
            self.contentStackView.widthAnchor.constraint(equalTo: self.scrollView.widthAnchor)
        ]
        constraints.append(contentsOf: contentStackViewConstraints)
        
        let loadingViewConstraints = [
            self.loadingView.topAnchor.constraint(equalTo: self.contentView.topAnchor),
            self.loadingView.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor),
            self.loadingView.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor),
            self.loadingView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor)
        ]
        constraints.append(contentsOf: loadingViewConstraints)
        
        self.constraints = constraints
    }
    
    private func configureStyle() {
        self.view.backgroundColor = self.ropcStep.theme.groupedBackgroundColor
        self.parent?.view.backgroundColor = self.ropcStep.theme.groupedBackgroundColor
        self.contentView.backgroundColor = .clear
        self.navigationFooterView.backgroundColor = .clear
    }
    
    private func configureTapOutsideToDismiss(){
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.tappedOutsideResponsiveView))
        tapGesture.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tapGesture)
    }
    
    public override func configureNavigationBar(_ navigationBar: UINavigationBar) {
        self.configureNavBarAsDefaultGrouped(withTheme: self.ropcStep.theme)
    }
    
    // MARK: Loading
    
    public func showLoading() {
        self.loginButton.isEnabled = false
        self.loadingView.isHidden = false
    }

    public func hideLoading() {
        self.loginButton.isEnabled = self.isValid
        self.loadingView.isHidden = true
    }
    
    private var credentials : Credentials? {
        guard let username = self.usernameField.value, username.isEmpty == false else {return nil}
        guard let password = self.passwordField.value, password.isEmpty == false else {return nil}
        return (username, password)
    }
    
    private var isValid : Bool {
        return self.credentials != nil
    }
    
    private func validateForm(){
        self.loginButton.isEnabled = self.isValid
    }
    
    @IBAction func tappedOutsideResponsiveView(){
        self.view.endEditing(false)
    }
    
    @IBAction func submit(){
        guard let credentials = self.credentials else {return}
        self.ropcStep.submitBlock?(self, credentials)
    }
}

extension UIViewController {
    
    fileprivate func registerForKeyboardNotifications(_ scrollView: UIScrollView?, bottomMargin: CGFloat = 0){
        self.registerForKeyboardWillShowNotification(scrollView, bottomMargin: bottomMargin)
        self.registerForKeyboardWillHideNotification(scrollView)
    }
    
    private func registerForKeyboardWillShowNotification(_ scrollView: UIScrollView? = nil, bottomMargin: CGFloat = 0, usingBlock block: ((CGSize?) -> Void)? = nil) {
        _ = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: nil, using: { notification -> Void in
            let userInfo = notification.userInfo!
            let keyboardSize = (userInfo[UIResponder.keyboardFrameEndUserInfoKey]! as AnyObject).cgRectValue.size
            
            if let scrollView = scrollView {
                let bottomSafeAreaInset = scrollView.superview?.safeAreaInsets.bottom ?? 0
                let contentInsets = UIEdgeInsets(top: scrollView.contentInset.top, left: scrollView.contentInset.left, bottom: keyboardSize.height + bottomMargin - bottomSafeAreaInset, right: scrollView.contentInset.right)
                scrollView.setContentInsetAndScrollIndicatorInsets(contentInsets)
            }
            
            block?(keyboardSize)
        })
    }
    
    private func registerForKeyboardWillHideNotification(_ scrollView: UIScrollView? = nil, usingBlock block: (() -> Void)? = nil) {
        _ = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: nil, using: { _ -> Void in
            
            if let scrollView = scrollView {
                let contentInsets = UIEdgeInsets(top: scrollView.contentInset.top, left: scrollView.contentInset.left, bottom: 0, right: scrollView.contentInset.right)
                scrollView.setContentInsetAndScrollIndicatorInsets(contentInsets)
            }
            
            block?()
        })
    }
    
}

extension UIScrollView {
    
    fileprivate func setContentInsetAndScrollIndicatorInsets(_ edgeInsets: UIEdgeInsets) {
        self.contentInset = edgeInsets
        self.scrollIndicatorInsets = edgeInsets
    }
    
}

extension MWROPCLoginViewController: MWROPCTextFieldDelegate {
    
    func onReturnTapped(textField: MWROPCTextField) {
        if textField === self.usernameField {
            self.passwordField.becomeFirstResponder()
        }else if textField === self.passwordField {
            if self.isValid {
                self.submit()
            }else{
                textField.resignFirstResponder()
            }
        }
    }
    
    func valueDidChange(textField: MWROPCTextField) {
        self.validateForm()
    }
    
}
