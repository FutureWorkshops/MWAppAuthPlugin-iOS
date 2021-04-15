//
//  MWAppAuthPlugin.swift
//  MWAppAuthPlugin
//
//  Created by Jonathan Flintham on 25/11/2020.
//

import Foundation
import MobileWorkflowCore

public struct MWAppAuthPlugin: Plugin {
    
    public static var allStepsTypes: [StepType] {
        return MWAppAuthStepType.allCases
    }
}

enum MWAppAuthStepType: String, StepType, CaseIterable {
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
