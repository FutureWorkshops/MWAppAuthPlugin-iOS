//
//  MWROPCTextField.swift
//  MWAppAuthPlugin
//
//  Created by Julien Hebert on 20/10/2021.
//

import UIKit
import MobileWorkflowCore

public protocol MWROPCTextFieldDelegate : class {
    func onReturnTapped(textField: MWROPCTextField)
    func valueDidChange(textField: MWROPCTextField)
}

public class MWROPCTextField: UIView {
    
    public weak var delegate : MWROPCTextFieldDelegate?
    
    public struct Config {
        public let title: String
        public let placeholder: String?
        public let isSecureTextEntry: Bool
        public let textContentType: UITextContentType
        
        public init(
            title: String,
            placeholder: String?,
            isSecureTextEntry: Bool = false,
            textContentType: UITextContentType
        ) {
            self.title = title
            self.placeholder = placeholder
            self.isSecureTextEntry = isSecureTextEntry
            self.textContentType = textContentType
        }
    }
    
    public var value: String? {
        return self.textField.text
    }
    
    public var isEnabled : Bool {
        get {
            return self.textField.isEnabled
        }
        set {
            self.textField.isEnabled = newValue
        }
    }
    
    private lazy var label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textColor = theme.primaryTextColor
        label.font = UIFont.preferredFont(forTextStyle: .subheadline, weight: .semibold)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }()
    
    private lazy var textField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = UIFont.preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.backgroundColor = .clear
        textField.clearButtonMode = .never
        textField.delegate = self
        return textField
    }()
    
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 5
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        return stackView
    }()
    
    public var theme: Theme = .current
    
    public init(theme: Theme) {
        self.theme = theme
        super.init(frame: .zero)
        self.stackView.addArrangedSubview(self.label)
        self.stackView.addArrangedSubview(self.textField)
        self.addSubview(self.stackView)
        self.configureConstraints()
        self.textField.addTarget(self, action: #selector(self.textFieldValueDidChange(textField:)), for: .editingChanged)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.becomeFirstResponder))
        self.addGestureRecognizer(tapGesture)
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureConstraints() {
        NSLayoutConstraint.activate([
            self.stackView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 0),
            self.stackView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: 0),
            self.stackView.topAnchor.constraint(equalTo: self.topAnchor, constant: 0),
            self.stackView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: 0)
        ])
    }
    
    public func configure(config: Config){
        self.label.text = config.title
        self.textField.placeholder = config.placeholder
        self.textField.isSecureTextEntry = config.isSecureTextEntry
        self.textField.textContentType = config.textContentType
    }
    
    public override func becomeFirstResponder() -> Bool {
        return self.textField.becomeFirstResponder()
    }
    
    public override func resignFirstResponder() -> Bool {
        return self.textField.resignFirstResponder()
    }
    
    @IBAction func textFieldValueDidChange(textField : UITextField){
        self.delegate?.valueDidChange(textField: self)
    }

}

extension MWROPCTextField : UITextFieldDelegate {
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let delegate = self.delegate{
            delegate.onReturnTapped(textField: self)
        }else{
            self.textField.resignFirstResponder()
        }
        return true
    }
    
}
