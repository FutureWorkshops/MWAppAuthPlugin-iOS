//
//  Error+Login.swift
//  AppAuth
//
//  Created by Igor Ferreira on 23/02/2022.
//

import Foundation

extension Error {
    var isAuthenticationError: Bool {
        guard let urlError = self as? URLError else { return false }
        switch(urlError.code.rawValue) {
        case 400, 401: return true
        default: return false
        }
    }
}
