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
    
    private let loginButton = ASAuthorizationAppleIDButton()
    weak var delegate: SignInWithAppleButtonTableViewCellDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    public func configureCell() {
        self.setupLoginButton()
        self.setupConstraints()
    }
    
    private func setupLoginButton() {
        self.loginButton.cornerRadius = 14
        self.loginButton.addTarget(self, action: #selector(self.didTapSignIn(_:)), for: .touchUpInside)
        self.loginButton.translatesAutoresizingMaskIntoConstraints = false
        
        self.backgroundColor = .secondarySystemBackground
        self.contentView.backgroundColor = .secondarySystemBackground
        
        self.contentView.addSubview(self.loginButton)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            self.loginButton.topAnchor.constraint(equalTo: self.contentView.safeAreaLayoutGuide.topAnchor, constant: 16),
            self.loginButton.leftAnchor.constraint(equalTo: self.contentView.safeAreaLayoutGuide.leftAnchor, constant: 16),
            self.loginButton.rightAnchor.constraint(equalTo: self.contentView.safeAreaLayoutGuide.rightAnchor, constant: -16),
            self.loginButton.bottomAnchor.constraint(lessThanOrEqualTo: self.contentView.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            self.loginButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    @objc private func didTapSignIn(_ button: UIButton) {
        self.delegate?.appleCell(self, didTapButton: button)
    }
}
