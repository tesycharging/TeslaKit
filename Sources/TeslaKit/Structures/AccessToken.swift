//
//  AccessToken.swift
//  TeslaApp
//
//  Created by Jaren Hamblin on 11/19/17.
//  Copyright © 2018 HamblinSoft. All rights reserved.
//
/*
import Foundation
import ObjectMapper
import CryptoKit

private let oAuthClientID: String = "81527cff06843c8634fdc09e8ac0abefb46ac849f38fe1e431c2ef2106796384"
private let oAuthWebClientID: String = "ownerapi"
private let oAuthClientSecret: String = "c7257eb71a564034f9419ee651c7d0e5f7aa6bfbd18bafb5c5c033b093bb2fa3"
private let oAuthScope: String = "openid email offline_access"
private let oAuthRedirectURI: String = "https://auth.tesla.com/void/callback"

public struct AccessToken {
	public var accessToken: String = ""
    public var tokenType: String = ""
    public var createdAt: Date = Date()
    public var expiresIn: TimeInterval = Date().TimeInterval
    public var refreshToken: String = ""
    public var idToken: String = ""
	
	public init() {}
	
	public init(accessToken: String) {
        self.accessToken = accessToken
    }
}

extension AccessToken: DataResponse {
    public mutating func mapping(map: Map) {
		accessToken <- map["response.access_token"]
		tokenType <- map["response.token_type"]
		createdAt <- map["response.created_at"]
		expiresIn <- map["response.expires_in"]
		refreshToken <- map["response.refresh_token"]
		idToken <- map["response.id_token"]
	}
}

/// Response Object
public enum AccessToken {

    /// AccessToken Request object containing the required information to receive an accessToken
    public struct Request {

        /// Grant type should be "password"
        public var grantType: String? = nil

        /// Tesla API owner api client id
        public var clientId: String? = nil

        /// Tesla API owner api client secret
        public var clientSecret: String? = nil

        /// The email address of a user
        public var email: String? = nil

        /// The password of a user
        public var password: String? = nil

        ///
        public init() {}

        ///
        public init(grantType: String?, clientId: String?, clientSecret: String?, email: String?, password: String?) {
            self.grantType = grantType
            self.clientId = clientId
            self.clientSecret = clientSecret
            self.email = email
            self.password = password
        }

    }

    /// The response object returned containing an accessToken
    public struct Response {

        /// The accessToken that needs to be included with each request to obtain vehicle data and send vehicle commands
        public var accessToken: String? = nil

        /// The type of token
        public var tokenType: String? = nil

        /// When the access token expires
        public var expiresIn: TimeInterval? = nil

        /// The date the access token was created at
        public var createdAt: Date? = nil

        /// A refresh token
        public var refreshToken: String? = nil
        
        /// Returns whether the accessToken obejct is valid or has expired
        public var isExpired: Bool {
            guard let createdAt = self.createdAt, let expiresIn = self.expiresIn, self.accessToken != nil && self.accessToken != "" else { return true }
            let expiryDate: Date = createdAt.addingTimeInterval(expiresIn)
            let isExpired: Bool = expiryDate <= Date()
            return isExpired
        }

        ///
        public init() {}

        ///
        public init(accessToken: String?, tokenType: String?, expiresIn: TimeInterval?, createdAt: Date?, refreshToken: String?) {
            self.accessToken = accessToken
            self.tokenType = tokenType
            self.expiresIn = expiresIn
            self.createdAt = createdAt
            self.refreshToken = refreshToken
        }
    }
}

///
extension AccessToken.Request: Mappable {

    public mutating func mapping(map: Map) {
        grantType <- map["grant_type"]
        clientId <- map["client_id"]
        clientSecret <- map["client_secret"]
        email <- map["email"]
        password <- map["password"]
    }
}

///
extension AccessToken.Response: Mappable {

    public mutating func mapping(map: Map) {
        accessToken <- map["access_token"]
        tokenType <- map["token_type"]
        expiresIn <- map["expires_in"]
        createdAt <- (map["created_at"], DateTransform())
        refreshToken <- map["refresh_token"]
    }
}
**/