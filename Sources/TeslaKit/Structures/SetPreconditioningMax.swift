//
//  SetPreconditioningMax.swift
//  Tesy
//
//  Created by David Lüthi on 23.12.20.
//

import Foundation
import ObjectMapper
//import TeslaKit

/// Toggles the climate controls between Max Defrost and the previous setting.
public struct SetPreconditioningMax: ImmutableMappable {

    public var isOn: Bool = true

    ///
    public init() {}


    /// Set the temperature target for the HVAC system.
    ///
    /// - Parameters:
    ///   - vehicleId: The id of the Vehicle. Example: 1.
    ///   - on:
    public init(isOn: Bool) {
        self.isOn = isOn
    }
    
    public init(map: Map) throws {
        isOn = try map.value("on")
    }
    
    public func mapping(map: Map) {
        isOn >>> map["on"]
    }
}
