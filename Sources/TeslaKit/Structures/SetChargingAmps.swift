//
//  SetCharingAmps.swift
//  TeslaKit
//
//  Created by David Lüthi on 25.08.2024.
//

import Foundation
import ObjectMapper

/// Set the charge limit to a custom percentage.
public struct SetChargingAmps {

    /// The percentage value Example: 75.
    public var value: Int = 0

    ///
    public init() {}


    /// Set the charge limit to a custom percentage.
    ///
    /// - Parameters:
    ///   - value: The value in Ampere.
    public init(value: Int) {
        self.value = value
    }
}

extension SetChargingAmps: Mappable {
    public mutating func mapping(map: Map) {
        value <- map["charging_amps"]
    }
}
