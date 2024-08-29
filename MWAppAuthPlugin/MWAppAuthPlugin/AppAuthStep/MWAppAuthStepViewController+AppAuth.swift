//
//  MWAppAuthStepViewController+AppAuth.swift
//  MWAppAuthPlugin
//
//  Created by Jonathan Flintham on 02/03/2021.
//

import UIKit
import MobileWorkflowCore
import AuthenticationServices
import CryptoKit

private let OAuthCodeChallengeMethodS256 = "S256"
private let OAuthResponseTypeCode = "code"

extension MWAppAuthStepViewController {
    
    func performOAuth(config: OAuth2Config) async {
        guard
            let oAuth2Path = self.appAuthStep.session.resolve(url: config.oAuth2Url)?.absoluteString,
            let oAuth2Url = URL(string: oAuth2Path)
        else { return }
        
        let authorizationEndpoint: URL
        let tokenEndpoint: URL
        
        if let tokenPath = config.oAuth2TokenUrl,
           !tokenPath.isEmpty,
           let tokenURL = URL(string: tokenPath) {
            authorizationEndpoint = oAuth2Url
            tokenEndpoint = tokenURL
        } else {
            authorizationEndpoint = oAuth2Url.appendingPathComponent(OAuthPaths.authorization)
            tokenEndpoint = oAuth2Url.appendingPathComponent(OAuthPaths.token)
        }
        
        self.showLoading()
        
        do {
            let codeVerifier = try self.generatePKCECode()
            let state = try self.generatePKCECode(size: 8)
            let codeChallenge = try self.generateCodeVerifier(code: codeVerifier)
            
            let fullValidURL = self.buildAuthenticationURL(
                baseURL: authorizationEndpoint,
                config: config,
                codeChallenge: codeChallenge,
                state: state
            )
            
            let response = try await self.authenticate(
                oAuth2Url: fullValidURL,
                callbackURLScheme: config.oAuth2RedirectScheme
            )
            
            guard let code = URLComponents(url: response, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "code" })?
                .value else {
                return await self.display(error: URLError(.init(rawValue: 403)))
            }
            
            let responseState = URLComponents(url: response, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "state" })?
                .value
            
            if responseState != nil, responseState != state {
                return await self.display(error: URLError(.badServerResponse))
            }
            
            
            let tokenResponse = try await fetchToken(
                tokenURL: tokenEndpoint,
                code: code,
                config: config,
                codeVerifier: codeVerifier
            )
            
            var credentials: [Credential] = [.init(
                type: CredentialType.token,
                value: tokenResponse.accessToken,
                expirationDate: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
            )]
            
            if let refreshToken = tokenResponse.refreshToken {
                credentials.append(.init(type: CredentialType.refreshToken, value: refreshToken))
            }
            
            await self.handle(tokens: credentials)
        } catch {
            await self.display(error: error)
        }
    }
    
    @MainActor
    private func display(error: Error) async {
        self.hideLoading()
        await self.show(error)
    }
    
    private func buildAuthenticationURL(
        baseURL: URL,
        config: OAuth2Config,
        codeChallenge: String,
        state: String
    ) -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return baseURL
        }
        
        var queryItems = components.queryItems ?? []
        queryItems.append(.init(name: "response_type", value: OAuthResponseTypeCode))
        
        if !config.oAuth2ClientId.isEmpty {
            queryItems.append(.init(name: "client_id", value: config.oAuth2ClientId))
        }
        if !config.oAuth2Scope.isEmpty {
            queryItems.append(.init(name: "scope", value: config.oAuth2Scope))
        }
        if !codeChallenge.isEmpty {
            queryItems.append(.init(name: "code_challenge", value: codeChallenge))
            queryItems.append(.init(name: "code_challenge_method", value: OAuthCodeChallengeMethodS256))
        }
        if !state.isEmpty {
            queryItems.append(.init(name: "state", value: state))
        }
        
        components.queryItems = queryItems
        return components.url ?? baseURL
    }
    
    private func authenticate(oAuth2Url: URL, callbackURLScheme: String?) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: oAuth2Url,
                callbackURLScheme: callbackURLScheme
            ) { response, error in
                if let error = error {
                    return continuation.resume(throwing: error)
                } else if let response = response {
                    return continuation.resume(returning: response)
                } else {
                    return continuation.resume(throwing: URLError(.badServerResponse))
                }
            }
            session.presentationContextProvider = self
            session.start()
        }
    }
    
    private func generateCodeVerifier(code: String) throws -> String {
        guard let data = code.data(using: .ascii) else {
            throw URLError(.init(rawValue: 400))
        }
        
        let digest = SHA256.hash(data: data)
            .map({ $0 })
        return base64URLEncode(octets: digest)
    }
    
    private func generatePKCECode(size: Int = 32) throws -> String {
        var octets = [UInt8](repeating: 0, count: size)
        let status = SecRandomCopyBytes(kSecRandomDefault, octets.count, &octets)
        guard status == errSecSuccess else {
            throw URLError(.init(rawValue: 400))
        }
        
        return base64URLEncode(octets: octets)
    }
    
    private func base64URLEncode<S>(octets: S) -> String where S : Sequence, UInt8 == S.Element {
        let data = Data(octets)
        return data
                .base64EncodedString()                    // Regular base64 encoder
                .replacingOccurrences(of: "=", with: "")  // Remove any trailing '='s
                .replacingOccurrences(of: "+", with: "-") // 62nd char of encoding
                .replacingOccurrences(of: "/", with: "_") // 63rd char of encoding
                .trimmingCharacters(in: .whitespaces)
    }
    
    private func fetchToken(
        tokenURL: URL,
        code: String,
        config: OAuth2Config,
        codeVerifier: String
    ) async throws -> ROPCResponse {
        
        var params: [String: String] = [
            "grant_type": "authorization_code",
            "client_id": config.oAuth2ClientId,
            "code": code,
            "code_verifier": codeVerifier
        ]
        if let secret = config.oAuth2ClientSecret {
            params["client_secret"] = secret
        }
        
        let paramsString = params.map({ "\($0.key)=\($0.value)" }).joined(separator: "&") // url encoding
        let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "=&"))
        let escapedParamsString = paramsString.addingPercentEncoding(withAllowedCharacters: allowedChars) ?? paramsString // e.g. '+' is reserved char for postman, and if unescaped and it gets replaced with a space char
        
        let task = URLAsyncTask<ROPCResponse>.build(
            url: tokenURL,
            method: .POST,
            body: escapedParamsString.data(using: .utf8),
            session: self.appAuthStep.session,
            headers: ["Content-Type": "application/x-www-form-urlencoded"],
            parser: { try ROPCResponse.parse(data: $0) }
        )
        
        return try await self.appAuthStep.services.perform(task: task, session: self.appAuthStep.session)
    }
    
    @MainActor
    private func handle(tokens: [Credential]) async {
        let result = self.appAuthStep.services.credentialStore.updateCredentials(tokens)
        switch result {
        case .success:
            self.goForward()
        case .failure(let error):
            await self.show(error)
        }
    }
}

// MARK: - Authorization Controller Presentation

extension MWAppAuthStepViewController: ASWebAuthenticationPresentationContextProviding {

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windows = self.view.window else {
            preconditionFailure()
        }
        
        return windows
    }
}

extension MWAppAuthStepViewController: ASAuthorizationControllerPresentationContextProviding {
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windows = self.view.window else {
            preconditionFailure()
        }
        
        return windows
    }
}
