//
//  TeslaEndpoint.swift
//  TeslaSwift
//
//  Created by Joao Nunes on 16/04/16.
//  Copyright © 2016 Joao Nunes. All rights reserved.
//

import Foundation

enum Endpoint {
    
    //@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    case oAuth2Authorization(auth: AuthCodeRequest)
    case oAuth2Token
    case oAuth2revoke(token: String)
}

extension Endpoint {
    
    var path: String {
        switch self {
            case .oAuth2Authorization:
                return "/oauth2/v3/authorize"
            case .oAuth2Token:
                return "/oauth2/v3/token"
            case .oAuth2revoke:
                return "/oauth2/v3/revoke"
        }
    }
    
    var method: String {
        switch self {
        case .oAuth2Token:
            return "POST"
            case .oAuth2Authorization, .oAuth2revoke:
            return "GET"
        }
    }

    var queryParameters: [URLQueryItem] {
        switch self {
            case let .oAuth2Authorization(auth):
                return auth.parameters()
            case let .oAuth2revoke(token):
                return [URLQueryItem(name: "token", value: token)]
            default:
                return []
        }
    }

    func baseURL(_ useMockServer: Bool = false) -> String {
        return "https://auth.tesla.com"
    }
}

