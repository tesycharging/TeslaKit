//
//  ErrorMessage.swift
//  TeslaKit
//
//  Created by David Lüthi on 17.12.2023
//  Copyright © 2023 David Lüthi. All rights reserved.
//

import Foundation
import ObjectMapper

@available(macOS 13.1, *)
public struct ErrorMessage: TKMappable {
    public var allValues: Map
  
    public var error: String = ""
    
    public var error_description: String = ""
    
    public var messages: String = ""

    ///
    public init() {
        allValues = Map(mappingType: .fromJSON, JSON: ["":""])
    }
}

@available(macOS 13.1, *)
extension ErrorMessage: DataResponse {
    public mutating func mapping(map: Map) {
        allValues = map
        error <- (map["error"])
        error_description <- map["error_description"]
        messages <- map["messages"]
    }
}
