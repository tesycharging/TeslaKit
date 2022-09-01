//
//  MobileAccess.swift
//  TeslaApp
//
//  Created by Jaren Hamblin on 11/25/17.
//  Copyright © 2018 HamblinSoft. All rights reserved.
//

import Foundation
import ObjectMapper

/// Determines if mobile access to the vehicle is enabled.
public struct MobileAccess: AllVehicleValues {
    public var allValues: Map

    ///
    public var response: Bool = false

    ///
    public init() {
		allValues = Map(mappingType: .fromJSON, JSON: ["":""])
	}

    ///
    public init(response: Bool) {
        self.response = response
    }
}

extension MobileAccess: DataResponse {
    public mutating func mapping(map: Map) {
		allValues = map
        response <- map["response"]
		self.printDescription()
    }
}
