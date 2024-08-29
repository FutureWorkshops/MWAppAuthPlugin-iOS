//
//  App.swift
//  MWAppAuth
//
//  Created by Igor Ferreira on 29/8/24.
//  Copyright © 2024 Future Workshops. All rights reserved.
//

import Foundation
import MobileWorkflowCore
import MWAppAuthPlugin

let app = AppRail(
    name: "Health Check",
    steps: [
        .restStack(id: "0dea5294-b253-46f1-b4bc-a61ccbd2bf1f", title: "Current User", url: "/users/current"),
        .appAuthStep(id: "16da25e8-0875-47e2-af3a-e539bc8c722b", title: "Login", options: [
            .signInSignInOauthItem(
                label: "Login with Doorkeeper",
                oAuth2ClientId: "K6rCtOXPFQLa5XTL8DCqAPa24atiX5o1N6PVCpqrGA0",
                oAuth2ClientSecret: "1mMg3L1hcYvysKGXf7Cnp8W5UHdosow7Q2W1ar94zw4",
                oAuth2Scope: "public",
                oAuth2RedirectScheme: "mww",
                oAuth2Url: "https://mw-health-check.herokuapp.com/oauth",
                oAuth2TokenUrl: "https://mw-health-check.herokuapp.com/token"
            )
        ], text: "Login with Doorkeeper")
    ],
    navigation: .primary(mainStep: "16da25e8-0875-47e2-af3a-e539bc8c722b", authenticationStep: "16da25e8-0875-47e2-af3a-e539bc8c722b"),
    servers: [
        .http(id: 125, url: "https://mw-health-check.herokuapp.com")
    ]
)
