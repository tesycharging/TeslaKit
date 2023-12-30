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
        email <- map["response.email"]
        full_name <- map["response.full_name"]
        profile_image_url <- (map["response.profile_image_url"], URLTransform())
    }
}

public struct URLTransform: TransformType {
    
    ///
    public typealias Object = URL
    
    ///
    public typealias JSON = String
    
    ///
    public func transformFromJSON(_ value: Any?) -> URL? {
        guard let value = value as? String else { return nil }
        let url = URL(string: value)
        return url
    }
    
    ///
    public func transformToJSON(_ value: URL?) -> String? {
        let urlStringOrNil: String? = value?.description
        return urlStringOrNil
    }
}
