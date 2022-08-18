//
//  Chargingsites.swift
//  Tesy
//
//  Created by David Lüthi on 08.10.21.
//

import Foundation
import ObjectMapper
//import TeslaKit

public struct Chargingsites {
    public var congestion_sync_time_utc_secs: TimeInterval = 0
    public var destination_charging: [DestinationCharging] = []
    public var superchargers: [Superchargers] = []
    public var timestamp: TimeInterval = 0
    public init() {}
}

extension Chargingsites: DataResponse {
    public mutating func mapping(map: Map) {
        let hasData: Bool = !(map.JSON["congestion_sync_time_utc_secs"] is TimeInterval)
        if hasData {
            congestion_sync_time_utc_secs <- map["response.congestion_sync_time_utc_secs"]
            destination_charging <- map["response.destination_charging"]
            superchargers <- map["response.superchargers"]
            timestamp <- map["response.timestamp"]
        } else {
            congestion_sync_time_utc_secs <- map["congestion_sync_time_utc_secs"]
            destination_charging <- map["destination_charging"]
            superchargers <- map["superchargers"]
            timestamp <- map["timestamp"]
        }
    }
}

public struct DestinationCharging {
    public var location: Location = Location()
    public var name: String = ""
    public var type: String = ""
    public var distance_miles: Double = 0
    public init() {}
}

extension DestinationCharging: DataResponse {
    public mutating func mapping(map: Map) {
        location <- map["location"]
        name <- map["name"]
        type <- map["type"]
        distance_miles <- map["distance_miles"]
    }
}

public struct Location: TKMappable {
    public var lat: Double = 0
    public var long: Double = 0
    public init() {}
}

extension Location {
    public mutating func mapping(map: Map) {
        lat <- map["lat"]
        long <- map["long"]
    }
}

public struct Superchargers {
    public var location: Location = Location()
    public var name: String = ""
    public var type: String = ""
    public var distance_miles: Double = 0
    public var available_stalls: Int = 0
    public var total_stalls: Int = 0
    private var site_closed: Int = 2
    public var siteclosed: Bool {
        site_closed != 0
    }
    public init() {}
}

extension Superchargers: DataResponse {
    public mutating func mapping(map: Map) {
        location <- map["location"]
        name <- map["name"]
        type <- map["type"]
        distance_miles <- map["distance_miles"]
        available_stalls <- map["available_stalls"]
        total_stalls <- map["total_stalls"]
        site_closed <- map["site_closed"]
    }
}

