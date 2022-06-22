//
//  SignInWithAppleButtonCell.swift
//  MWAppAuthPlugin
//
//  Created by Eric Sans on 8/2/21.
//

import UIKit
import AuthenticationServices
import MobileWorkflowCore

protocol SignInWithAppleButtonTableViewCellDelegate: AnyObject {
    func appleCell(_ cell: SignInWithAppleButtonTableViewCell, didTapButton button: UIButton)
}

final class SignInWithAppleButtonTableViewCell: UITableViewCell {
    
    private var loginButton: ASAuthorizationAppleIDButton?
    weak var delegate: SignInWithAppleButtonTableViewCellDelegate?
    
    public var theme: Theme = .current {
        didSet {
            self.configureCell()
        }
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.configureCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.configureCell()
    }
    
    private func configureCell() {
        
        self.backgroundColor = self.theme.primaryBackgroundColor
        self.contentView.backgroundColor = self.theme.primaryBackgroundColor
        
        self.setupLoginButton()
    }
    
    private func setupLoginButton() {
        self.loginButton?.removeFromSuperview() // removes previous constraints
        
        let loginButton = ASAuthorizationAppleIDButton(authorizationButtonType: .signIn, authorizationButtonStyle: self.traitCollection.userInterfaceStyle == .dark ? .white : .black)
        loginButton.cornerRadius = self.theme.buttonCornerRadius
        loginButton.addTarget(self, action: #selector(self.didTapSignIn(_:)), for: .touchUpInside)
        loginButton.translatesAutoresizingMaskIntoConstraints = false
        self.loginButton = loginButton
        self.contentView.addSubview(loginButton)
        
        NSLayoutConstraint.activate([
            loginButton.topAnchor.constraint(equalTo: self.contentView.safeAreaLayoutGuide.topAnchor, constant: 12),
            loginButton.leftAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.leftAnchor, constant: 0),
            loginButton.rightAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.rightAnchor, constant: 0),
            loginButton.bottomAnchor.constraint(lessThanOrEqualTo: self.contentView.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            loginButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    @objc private func didTapSignIn(_ button: UIButton) {
        self.delegate?.appleCell(self, didTapButton: button)
    }
}
