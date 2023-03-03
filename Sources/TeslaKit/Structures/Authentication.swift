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
import os

private let oAuthWebClientID: String = "ownerapi"
private let oAuthScope: String = "openid+email+offline_access"
private let oAuthRedirectURI: String = "https://auth.tesla.com/void/callback"
private let oAuthresponseType: String = "code"
private let oAuthcodeChallengeMethod = "S256"


public struct AuthToken {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: AuthToken.self))
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
            AuthToken.logger.error("\(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

//STEP 3 : Exchange code for access token
// used the codeVerifier generated in AuthCodeRequest
class AuthTokenRequestWeb: Encodable {

    enum GrantType: String, Encodable {
        case refreshToken = "refresh_token"
        case authorizationCode = "authorization_code"
    }

    var grantType: GrantType
    var clientID: String = oAuthWebClientID
    var codeVerifier: String?
    var code: String?
    var redirectURI: String?
    var refreshToken: String?
    var scope: String?

    init(_ codeVerifier: String = "", grantType: GrantType = .authorizationCode, code: String? = nil, refreshToken: String? = nil) {
        if grantType == .authorizationCode {
            self.codeVerifier = codeVerifier
            self.code = code
            self.redirectURI = oAuthRedirectURI //"https://auth.tesla.com/void/callback"
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
        case code = "code"
        case redirectURI = "redirect_uri"
        case refreshToken = "refresh_token"
        case codeVerifier = "code_verifier"
        case scope = "scope"
    }
}

//STEP 1 : Obtain TESLA login page to enter your authentication details into
@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public class AuthCodeRequest: Encodable {
    let clientID = oAuthWebClientID //"ownerapi"
    let redirectURI = oAuthRedirectURI //"https://auth.tesla.com/void/callback"
    let responseType = oAuthresponseType //"code"
    let scope = oAuthScope  //"openid email offline_access"
    let codeChallenge: String
    let codeChallengeMethod = oAuthcodeChallengeMethod //"S256"
    let state: String
    let codeVerifier: String //verifier used in the token request

    init() {
        let data = Data.secureRandomData(count: 32)
        self.codeChallenge = Data(data.base64URL.utf8).sha256base64URL
        self.codeVerifier = data.base64URL //verifier used in the token request
        
        self.state = Data.secureRandomData(count: 16).base64URL
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
            URLQueryItem(name: CodingKeys.clientID.rawValue, value: clientID), //"ownerapi"
            URLQueryItem(name: CodingKeys.redirectURI.rawValue, value: redirectURI), //"https://auth.tesla.com/void/callback"
            URLQueryItem(name: CodingKeys.responseType.rawValue, value: responseType), //"code"
            URLQueryItem(name: CodingKeys.scope.rawValue, value: scope), //"openid email offline_access"
            URLQueryItem(name: CodingKeys.codeChallenge.rawValue, value: codeChallenge), //self.codeChallenge
            URLQueryItem(name: CodingKeys.codeChallengeMethod.rawValue, value: codeChallengeMethod), //"S256"
            URLQueryItem(name: CodingKeys.state.rawValue, value: state) //self.state
        ]
    }
}

extension Data {
    static func secureRandomData(count: Int) -> Data {
        var bytes = [Int8](repeating: 0, count: count)
        //fill bytes wiht secure random data
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        //A status of errSecSucess indicates success
        if status == errSecSuccess {
            //Convert bytes to data
            let data = Data(bytes: bytes, count: count)
            return data
        } else {
            return Data("0".utf8)
        }
    }
    
    var base64URL: String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
    
    var sha256base64URL: String {
        let hashed = SHA256.hash(data: self)
        return Data(hashed).base64URL
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
