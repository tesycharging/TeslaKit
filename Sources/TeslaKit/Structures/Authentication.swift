//
//  AuthToken.swift
//  TeslaKit
//
//  Update by David Lüthi on 10.06.2021
//  based on code from Joao Nunes on 04/03/16.
//  Copyright © 2022 David Lüthi. All rights reserved.
//

import Foundation
import CryptoKit
import ObjectMapper

private let oAuthClientID: String = "81527cff06843c8634fdc09e8ac0abefb46ac849f38fe1e431c2ef2106796384"
private let oAuthWebClientID: String = "ownerapi"
private let oAuthClientSecret: String = "c7257eb71a564034f9419ee651c7d0e5f7aa6bfbd18bafb5c5c033b093bb2fa3"
private let oAuthScope: String = "openid email offline_access"
private let oAuthRedirectURI: String = "https://auth.tesla.com/void/callback"


public struct AuthToken {
    public var allValues: Map
	public var accessToken: String?
    public var tokenType: String?
    public var createdAt: Date? = Date()
    public var expiresIn: TimeInterval?
    public var refreshToken: String?
    public var idToken: String?
	
	public init() {
		allValues = Map(mappingType: .fromJSON, JSON: ["":""])
	}
	
	public init(accessToken: String) {
        self.accessToken = accessToken
		allValues = Map(mappingType: .fromJSON, JSON: ["":""])
    }
	
	public var isValid: Bool {
        if let createdAt = createdAt, let expiresIn = expiresIn {
            return -createdAt.timeIntervalSinceNow < expiresIn
        } else {
            return false
        }
    }
	
	public var isOAuth: Bool {
        // idToken is only present on the new oAuth authentications
        return idToken != nil
    }
}

extension AuthToken: DataResponse {
    public mutating func mapping(map: Map) {
		allValues = map
		accessToken <- map["access_token"]
		tokenType <- map["token_type"]
		createdAt <- map["created_at"]
		expiresIn <- map["expires_in"]
		refreshToken <- map["refresh_token"]
		idToken <- map["id_token"]
	}
    
    public static func loadToken(jsonString: String) -> AuthToken? {
        let data = Data(jsonString.utf8)
        do {
            let json: Any = try JSONSerialization.jsonObject(with: data)
            return Mapper<AuthToken>().map(JSONObject: json)
        } catch let error {
            print(error.localizedDescription)
            return nil
        }
    }
}


class AuthTokenRequestWeb: Encodable {

    enum GrantType: String, Encodable {
        case refreshToken = "refresh_token"
        case authorizationCode = "authorization_code"
    }

    var grantType: GrantType
    var clientID: String = oAuthWebClientID
    var clientSecret: String = oAuthClientSecret

    var codeVerifier: String?
    var code: String?
    var redirectURI: String?

    var refreshToken: String?
    var scope: String?

    init(grantType: GrantType = .authorizationCode, code: String? = nil, refreshToken: String? = nil) {
        if grantType == .authorizationCode {
            codeVerifier = oAuthClientID.codeVerifier
            self.code = code
            redirectURI = oAuthRedirectURI
        } else if grantType == .refreshToken {
            self.refreshToken = refreshToken
            self.scope = oAuthScope
        }
        self.grantType = grantType
    }

    // MARK: Codable protocol

    enum CodingKeys: String, CodingKey {
        typealias RawValue = String

        case grantType = "grant_type"
        case clientID = "client_id"
        case clientSecret = "client_secret"
        case code = "code"
        case redirectURI = "redirect_uri"
        case refreshToken = "refresh_token"
        case codeVerifier = "code_verifier"
        case scope = "scope"
    }
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public class AuthCodeRequest: Encodable {

    var responseType: String = "code"
    var clientID = oAuthWebClientID
    var clientSecret = oAuthClientSecret
    var redirectURI = oAuthRedirectURI
    var scope = oAuthScope
    let codeChallenge: String
    var codeChallengeMethod = "S256"
    var state = "TesyCharging"

    init() {
        self.codeChallenge = clientID.codeVerifier.challenge
    }

    // MARK: Codable protocol
    enum CodingKeys: String, CodingKey {
        typealias RawValue = String

        case clientID = "client_id"
        case redirectURI = "redirect_uri"
        case responseType = "response_type"
        case scope = "scope"
        case codeChallenge = "code_challenge"
        case codeChallengeMethod = "code_challenge_method"
        case state = "state"
    }

    func parameters() -> [URLQueryItem] {
        return[
            URLQueryItem(name: CodingKeys.clientID.rawValue, value: clientID),
            URLQueryItem(name: CodingKeys.redirectURI.rawValue, value: redirectURI),
            URLQueryItem(name: CodingKeys.responseType.rawValue, value: responseType),
            URLQueryItem(name: CodingKeys.scope.rawValue, value: scope),
            URLQueryItem(name: CodingKeys.codeChallenge.rawValue, value: codeChallenge),
            URLQueryItem(name: CodingKeys.codeChallengeMethod.rawValue, value: codeChallengeMethod),
            URLQueryItem(name: CodingKeys.state.rawValue, value: state)
        ]
    }
}

extension String {
    var codeVerifier: String {
        let verifier = self.data(using: .utf8)!.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
        return verifier
    }

    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    var challenge: String {
        let hash = self.sha256
        let challenge = hash.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
        return challenge
    }

    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    var sha256:String {
        get {
            let inputData = Data(self.utf8)
            let hashed = SHA256.hash(data: inputData)
            let hashString = hashed.compactMap { String(format: "%02x", $0) }.joined()
            return hashString
        }
    }

    func base64EncodedString() -> String {
        let inputData = Data(self.utf8)
        return inputData.base64EncodedString()
    }
}


public struct BoolResponse {
    public var response: Bool
    public var allValues: Map
    
    public init() {
        allValues = Map(mappingType: .fromJSON, JSON: ["":""])
        response = false
    }
}

extension BoolResponse: DataResponse {
    
    public mutating func mapping(map: Map) {
        allValues = map
        response <- map["response"]
    }
}
