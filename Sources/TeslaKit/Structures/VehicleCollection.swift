//
//  VehicleCollection.swift
//  TeslaKit
//
//  Created by Jaren Hamblin on 11/20/17.
//  Copyright © 2018 HamblinSoft. All rights reserved.
//

import Foundation
import ObjectMapper

/// Retrieve a list of your owned vehicles (includes vehicles not yet shipped!)
@available(macOS 13.1, *)
public struct VehicleCollection {

    ///
    public var vehicles: [Vehicle] = []

    ///
    public init() {}

    ///
    public init(vehicles: [Vehicle]) {
        self.vehicles = vehicles
    }
}

@available(macOS 13.1, *)
extension VehicleCollection: Mappable {
    public mutating func mapping(map: Map) {
        vehicles <- map["response"]
    }
}
