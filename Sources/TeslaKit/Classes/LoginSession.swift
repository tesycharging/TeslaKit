//
//  File.swift
//  
//
//  Created by David Lüthi on 23.02.23.
//

import Foundation
import SwiftUI
import CoreData
import ObjectMapper
import AuthenticationServices
import Combine

import WebKit
#if canImport(UIKit)
import UIKit
#endif
import os

#if os(macOS)
public typealias ASPresentationAnchor = NSWindow
#else
public typealias ASPresentationAnchor = UIWindow
#endif

@available(macOS 13.1, *)
public class LoginSession: ViewController {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: LoginSession.self))
    
    public var teslaAPI: TeslaAPI
    public var callbackURLScheme: String
    private var webAuthSession: ASWebAuthenticationSession?
    
    
    public init(teslaAPI: TeslaAPI, callbackURLScheme: String) {
        self.teslaAPI = teslaAPI
        self.callbackURLScheme = callbackURLScheme
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @available(*, deprecated, message: "use WebLogin")
    public func getAuthTokenWithWebLogin(completion: @escaping(Result<AuthToken, Error>) -> Void) {
        let codeRequest = AuthCodeRequest()
        let endpoint = Endpoint.oAuth2Authorization(auth: codeRequest)
        var urlComponents = URLComponents(string: endpoint.baseURL())
        urlComponents?.path = endpoint.path
        urlComponents?.queryItems = endpoint.queryParameters
        guard let safeUrlComponents = urlComponents else {
            completion(.failure(TeslaError.authenticationFailed(msg: "no url")))
            return
        }
        
        self.webAuthSession = ASWebAuthenticationSession(url: safeUrlComponents.url!, callbackURLScheme: callbackURLScheme, completionHandler: { (callback, error) in
            guard error == nil, let callbackURL = callback, let queryItems = URLComponents(string: callbackURL.absoluteString)?.queryItems, let code = queryItems.first(where: { $0.name == "code" })?.value, let state = queryItems.first(where: { $0.name == "state" }), "\(state)" == "state=\(codeRequest.state)" else {
                completion(.failure(TeslaError.authenticationFailed(msg: "An error occurred when attempting to sign in.")))
                return
            }
            
            self.teslaAPI.getAuthenticationTokenForWeb(codeRequest.codeVerifier, code: code) { (result: Result<AuthToken, Error>) in
                completion(result)
                switch result {
                case .success(let token):
                    LoginSession.logger.debug("\(token.toJSON(), privacy: .public)")
                case .failure(let error):
                    LoginSession.logger.error("\(error.localizedDescription, privacy: .public)")
                }
            }
        })
        
        // Run the session
        webAuthSession?.presentationContextProvider = self
        webAuthSession?.prefersEphemeralWebBrowserSession = true
        if webAuthSession!.start() {
            LoginSession.logger.debug("\("Failed to start ASWebAuthenticationSession", privacy: .public)")
        }
    }
}


@available(macOS 13.1, *)
extension LoginSession: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}

