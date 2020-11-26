//
//  MWAppAuthPlugin.swift
//  MWAppAuthPlugin
//
//  Created by Jonathan Flintham on 25/11/2020.
//

import Foundation
import MobileWorkflowCore

public struct MWAppAuthPlugin: MobileWorkflowPlugin {
    
    public static var allStepsTypes: [MobileWorkflowStepType] {
        return MWAppAuthStepType.allCases
    }
}

enum MWAppAuthStepType: String, MobileWorkflowStepType, CaseIterable {
    case networkOAuth2
    
    var typeName: String {
        return self.rawValue
    }
    
    var stepClass: MobileWorkflowStep.Type {
        switch self {
        case .networkOAuth2: return MWAppAuthStep.self
        }
    }
}
