//
//  VehicleCommandResponse.swift
//  TeslaApp
//
//  Created by Jaren Hamblin on 11/24/17.
//  Copyright © 2018 HamblinSoft. All rights reserved.
//

import Foundation
import ObjectMapper

/// The vehicle command response object indicating whether the command was issued successfully
public struct CommandResponse {
    public var allValues: Map
    
    /// Commmand result
    public var result: Bool = false

    /// Reason for the command result
    public var reason: String?

    /// Error
    public var error: String?

    /// Error Description
    public var errorDescription: String?

    ///
    public var allErrorMessages: String {
        return [self.errorDescription, self.reason, self.errorDescription].compactMap{$0}.joined(separator: ". ")
    }

    ///
    public init() {
        allValues = Map(mappingType: .fromJSON, JSON: ["":""])
    }

    ///
    public init(result: Bool, reason: String) {
        self.result = result
        self.reason = reason
        self.error = reason
        allValues = Map(mappingType: .fromJSON, JSON: ["":""])
    }
}

extension CommandResponse: DataResponse {
    public mutating func mapping(map: Map) {
        allValues = map
        result <- map["response.result"]
        reason <- map["response.reason"]
        error <- map["error"]
        errorDescription <- map["error_description"]
    }
}
