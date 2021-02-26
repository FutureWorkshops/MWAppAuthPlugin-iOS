//
//  SignInWithAppleButtonCell.swift
//  MWAppAuthPlugin
//
//  Created by Eric Sans on 8/2/21.
//

import UIKit
import AuthenticationServices

protocol SignInWithAppleButtonTableViewCellDelegate: class {
    func appleCell(_ cell: SignInWithAppleButtonTableViewCell, didTapButton button: UIButton)
}

final class SignInWithAppleButtonTableViewCell: UITableViewCell {
    
    private var loginButton: ASAuthorizationAppleIDButton?
    weak var delegate: SignInWithAppleButtonTableViewCellDelegate?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.configureCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureCell() {
        
        self.backgroundColor = .secondarySystemBackground
        self.contentView.backgroundColor = .secondarySystemBackground
        
        self.setupLoginButton()
        self.setupConstraints()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if previousTraitCollection?.userInterfaceStyle != self.traitCollection.userInterfaceStyle {
            self.configureCell()
        }
    }
    
    private func setupLoginButton() {
        self.loginButton?.removeFromSuperview()
        let loginButton = ASAuthorizationAppleIDButton(authorizationButtonType: .signIn, authorizationButtonStyle: self.traitCollection.userInterfaceStyle == .dark ? .white : .black)
        loginButton.cornerRadius = 14
        loginButton.addTarget(self, action: #selector(self.didTapSignIn(_:)), for: .touchUpInside)
        loginButton.translatesAutoresizingMaskIntoConstraints = false
        self.loginButton = loginButton
        self.contentView.addSubview(loginButton)
    }
    
    private func setupConstraints() {
        guard let loginButton = self.loginButton else { preconditionFailure() }
        NSLayoutConstraint.activate([
            loginButton.topAnchor.constraint(equalTo: self.contentView.safeAreaLayoutGuide.topAnchor, constant: 16),
            loginButton.leftAnchor.constraint(equalTo: self.contentView.safeAreaLayoutGuide.leftAnchor, constant: 16),
            loginButton.rightAnchor.constraint(equalTo: self.contentView.safeAreaLayoutGuide.rightAnchor, constant: -16),
            loginButton.bottomAnchor.constraint(lessThanOrEqualTo: self.contentView.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            loginButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    @objc private func didTapSignIn(_ button: UIButton) {
        self.delegate?.appleCell(self, didTapButton: button)
    }
}
