//
//  AuthToken.swift
//  TeslaKit
//
//  Update by David Lüthi on 10.06.2021
//  based on code from Joao Nunes on 04/03/16.
//  Copyright © 2022 David Lüthi. All rights reserved.
//

import Foundation
import ObjectMapper
import os


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
