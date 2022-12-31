//
//  RemoteAutoSeatClimateReques.swift
//  
//
//  Created by David Lüthi on 27.12.22.
//

import Foundation
import ObjectMapper

public struct RemoteAutoSeatClimateRequest: TKMappable {
    
    public var auto_seat_position: SeatHeater?
    
    public var auto_climate_on: Bool = false
    
    public init(auto_seat_position: SeatHeater, auto_climate_on: Bool) {
        self.auto_seat_position = auto_seat_position
        self.auto_climate_on = auto_climate_on
    }

    ///
    public mutating func mapping(map: Map) {
        auto_seat_position <- (map["auto_seat_position"], EnumTransform())
        auto_climate_on <- map["auto_climate_on"]
    }
}
