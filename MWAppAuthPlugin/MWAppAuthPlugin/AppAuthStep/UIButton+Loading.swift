//
//  UIButton+Loading.swift
//  MWAppAuthPlugin
//
//  Created by Julien Hebert on 09/12/2021.
//

import UIKit

private let ButtonActivityIndicatorTag = 654645

private class UIActivityIndicatorViewWithStorage : UIActivityIndicatorView {
    var buttonTitle: String?
}

extension UIButton {
    
    func startLoading() {
        
        guard self.viewWithTag(ButtonActivityIndicatorTag) == nil else {return}
        
        self.isUserInteractionEnabled = false
        
        let activityIndicatorView = UIActivityIndicatorViewWithStorage()
        activityIndicatorView.style = .medium
        activityIndicatorView.hidesWhenStopped = true
        activityIndicatorView.color = self.titleColor(for: .normal)
        activityIndicatorView.tag = ButtonActivityIndicatorTag
        activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        activityIndicatorView.buttonTitle = self.title(for: .normal)
        self.addSubview(activityIndicatorView)
        
        self.addConstraint(NSLayoutConstraint(item: self, attribute: .centerX, relatedBy: .equal, toItem: activityIndicatorView, attribute: NSLayoutConstraint.Attribute.centerX, multiplier: 1.0, constant: 0.0))
        self.addConstraint(NSLayoutConstraint(item: self, attribute: .centerY, relatedBy: .equal, toItem: activityIndicatorView, attribute: NSLayoutConstraint.Attribute.centerY, multiplier: 1.0, constant: 0.0))
        
        self.setTitle("", for: .normal)
        
        activityIndicatorView.startAnimating()
        
    }
    
    func stopLoading() {
        
        self.isUserInteractionEnabled = true
        
        if let activityIndicatorView = self.viewWithTag(ButtonActivityIndicatorTag) as? UIActivityIndicatorViewWithStorage {
            self.setTitle(activityIndicatorView.buttonTitle, for: .normal)
            activityIndicatorView.stopAnimating()
            activityIndicatorView.removeFromSuperview()
        }
        
    }
}
