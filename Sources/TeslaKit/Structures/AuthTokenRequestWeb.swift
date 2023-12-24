//
//  AuthTokenRequest.swift
//  TeslaKit
//
//  Created by David Lüthi on 17.12.2023
//  Copyright © 2023 David Lüthi. All rights reserved.
//

import Foundation
import ObjectMapper
import CryptoKit

public enum GrantType: String {
    case refreshToken = "refresh_token"
    case authorizationCode = "authorization_code"
    case client_credentials = "client_credentials"
}

public struct AuthTokenRequestWeb {

    ///
    public var grantType: GrantType
    public var clientID: String
    public var codeVerifier: String?
    public var code: String?
    public var refreshToken: String?
    public var scope: String?
    public var client_secret: String?
    public var redirect_uri: String?
    public var audience: String?

  

    /*
     inoffical API
    */
    init(_ codeVerifier: String = "", grantType: GrantType = .authorizationCode, code: String? = nil, refreshToken: String? = nil) {
        self.grantType = grantType
        self.clientID = "ownerapi"
        if grantType == .authorizationCode {
            self.code = code
            self.codeVerifier = codeVerifier
            self.redirect_uri = "https://auth.tesla.com/void/callback"
        } else if grantType == .refreshToken {
            self.refreshToken = refreshToken
            self.scope = "openid offline_access user_data vehicle_device_data vehicle_cmds vehicle_charging_cmds"
        }
    }
    
    /*
     Token Request of API
     */
    init(grantType: GrantType = .authorizationCode, clientID: String, client_secret: String? = nil, redirect_uri: String? = nil, code: String? = nil, refreshToken: String? = nil) {
        self.grantType = grantType
        self.clientID = clientID
        if grantType == .authorizationCode {
            self.client_secret = client_secret
            self.redirect_uri = redirect_uri
            self.audience = "https://fleet-api.prd.na.vn.cloud.tesla.com"
            self.code = code
        } else if grantType == .refreshToken {
            self.refreshToken = refreshToken
        }
    }
    
    /**
     Generating a partner authentication token
     */
    init(clientID: String, client_secret: String, scope: String) {
        self.grantType = .client_credentials
        self.clientID = clientID
        self.client_secret = client_secret
        self.scope = scope
        self.audience = "https://fleet-api.prd.na.vn.cloud.tesla.com"
    }
}

extension AuthTokenRequestWeb: Mappable {
    public mutating func mapping(map: Map) {
        grantType <- (map["grant_type"], EnumTransform())
        clientID <- map["client_id"]
        codeVerifier <- map["code_verifier"]
        client_secret <- map["client_secret"]
        audience <- map["audience"]
        redirect_uri <- map["redirect_uri"]
        code <- map["code"]
        scope <- map["scope"]
        refreshToken <- map["refresh_token"]
    }
}

public struct RegisterAccount {

    ///
    public var domain: String = ""

    ///
    public init() {}

    ///
    public init(domain: String) {
        self.domain = domain
    }
}

extension RegisterAccount: Mappable {
    public mutating func mapping(map: Map) {
        domain <- map["domain"]
    }
}

public struct AuthCodeRequest {
    public var clientID : String
    public var redirectURI : String
    public var responseType : String
    public var scope : String
    public var codeChallenge: String?
    public var codeChallengeMethod : String?
    public var state: String
    public var codeVerifier: String? //verifier used in the token request
    public var locale: String?
    public var prompt: String?
    private var unofficialAPI: Bool

    public init() {
        unofficialAPI = true
        clientID = "ownerapi"
        redirectURI = "https://auth.tesla.com/void/callback"
        responseType = "code"
        scope = "openid offline_access user_data vehicle_device_data vehicle_cmds vehicle_charging_cmds"
        codeChallengeMethod = "S256"
        let data = Data.secureRandomData(count: 32)
        self.codeChallenge = Data(data.base64URL.utf8).sha256base64URL
        self.codeVerifier = data.base64URL //verifier used in the token request
        self.state = Data.secureRandomData(count: 16).base64URL
    }

    init(clientID: String, redirect_uri: String, scope: String) {
        unofficialAPI = false
        self.clientID = clientID
        self.redirectURI = redirect_uri
        self.state = Data.secureRandomData(count: 16).base64URL
        self.locale = Locale.preferredLanguages[0]
        self.prompt = "login"
        self.responseType = "code"
        self.scope = scope
        self.state = Data.secureRandomData(count: 16).base64URL
    }

    func parameters() -> [URLQueryItem] {
        if unofficialAPI {
            return[
                URLQueryItem(name: "client_id", value: clientID), //"ownerapi"
                URLQueryItem(name: "redirect_uri", value: redirectURI), //"https://auth.tesla.com/void/callback"
                URLQueryItem(name: "response_type", value: responseType), //"code"
                URLQueryItem(name: "scope", value: scope), //"openid email offline_access"
                URLQueryItem(name: "code_challenge", value: codeChallenge), //self.codeChallenge
                URLQueryItem(name: "code_challenge_method", value: codeChallengeMethod), //"S256"
                URLQueryItem(name: "state", value: state) //self.state
            ]
        } else {
            return[
                URLQueryItem(name: "client_id", value: clientID),
                URLQueryItem(name: "locale", value: locale),
                URLQueryItem(name: "prompt", value: prompt),
                URLQueryItem(name: "redirect_uri", value: redirectURI),
                URLQueryItem(name: "response_type", value: responseType),
                URLQueryItem(name: "scope", value: scope),
                URLQueryItem(name: "state", value: state)
            ]
        }
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

@available(macOS 13.1, *)
public struct RegionAccount: TKMappable {
    public var allValues: Map
    public var region: String = ""
    public var fleet_api_base_url: String = ""

    ///
    public init() {
        allValues = Map(mappingType: .fromJSON, JSON: ["":""])
    }
}

@available(macOS 13.1, *)
extension RegionAccount: DataResponse {
    public mutating func mapping(map: Map) {
        allValues = map
        region <- (map["response.region"])
        fleet_api_base_url <- map["response.fleet_api_base_url"]
    }
}
