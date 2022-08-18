//
//  TriggerHomelink.swift
//  Tesy
//
//  Created by David Lüthi on 16.01.21.
//

import Foundation
import ObjectMapper

public struct TriggerHomelink {
    
    public var lat: Double = 0
    
    public var lon: Double = 0
    
    public init() {}
    
    public init(lat: Double, lon: Double ) {
        self.lat = lat
        self.lon = lon
    }
}

extension TriggerHomelink: Mappable {
    public init?(map: Map) {
        print("INIT TRIGGERHOMELINK")
    }
    
    public mutating func mapping(map: Map) {
        lat <- map["lat"]
        lon <- map["lon"]
    }
}
