//
//  MWAppAuthPlugin.swift
//  MWAppAuthPlugin
//
//  Created by Jonathan Flintham on 25/11/2020.
//

import Foundation
import MobileWorkflowCore

public struct MWAppAuthPluginStruct: Plugin {
    
    public static var allStepsTypes: [StepType] {
        return MWAppAuthStepType.allCases
    }
    
    public static func buildInterceptors(credentialStore: CredentialStoreProtocol) -> [AsyncTaskInterceptor] {
        return [
            RefreshTokenInterceptor(credentialStore: credentialStore),
            OAuthSessionResponseInterceptor(credentialStore: credentialStore)
        ]
    }
}

enum MWAppAuthStepType: String, StepType, CaseIterable {
    case networkOAuth2
    
    var typeName: String {
        return self.rawValue
    }
    
    var stepClass: BuildableStep.Type {
        switch self {
        case .networkOAuth2: return MWAppAuthStep.self
        }
    }
}
