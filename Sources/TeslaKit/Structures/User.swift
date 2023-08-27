//
//  User.swift
//  
//
//  Created by David Lüthi on 24.08.23.
//

import Foundation
import ObjectMapper

@available(macOS 13.1, *)
public struct User: TKMappable {
    public var allValues: Map
  
    public var email: String = ""
    
    public var full_name: String = ""
    
    public var profile_image_url: URL?

    ///
    public init() {
        allValues = Map(mappingType: .fromJSON, JSON: ["":""])
    }
}

@available(macOS 13.1, *)
extension User: DataResponse {
    public mutating func mapping(map: Map) {
        allValues = map
        email <- (map["response.email"])
        full_name <- map["response.full_name"]
        var url = ""
        url <- map["response.profile_image_url"]
        profile_image_url = URL(string: url)!
    }
}
