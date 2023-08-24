//
//  User.swift
//  
//
//  Created by David Lüthi on 24.08.23.
//

import Foundation
import ObjectMapper

public struct User: TKMappable {
    public var allValues: Map
  
    public var email: String = "demo@tesla.com"
    
    public var full_name: String = "Demo User"
    
    public var profile_image_url: URL = URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Purple126/v4/bd/41/3e/bd413e6b-111e-4078-a3c6-abeb51de6c25/AppIcon-0-2x-4-0-85-220.png/1200x600wa.png")!

    ///
    public init() {
        allValues = Map(mappingType: .fromJSON, JSON: ["":""])
    }
}

@available(macOS 13.1, *)
extension User: DataResponse {
    public mutating func mapping(map: Map) {
        allValues = map
        email <- (map["email"])
        full_name <- map["full_name"]
        var url = ""
        url <- map["profile_image_url"]
        profile_image_url = URL(string: url)!
    }
}
