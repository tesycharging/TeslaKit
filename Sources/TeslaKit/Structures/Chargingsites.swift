//
//  Chargingsites.swift
//  TeslaKit
//
//  Update by David Lüthi on 10.06.2021
//  Copyright © 2022 David Lüthi. All rights reserved.
//


import Foundation
import ObjectMapper
import MapKit

public struct Chargingsites {
    public var allValues: Map
    public var congestion_sync_time_utc_secs: TimeInterval = 0
    public var destination_charging: [DestinationCharging] = []
    public var superchargers: [Superchargers] = []
    public var timestamp: TimeInterval = 0
    public init() {
        allValues = Map(mappingType: .fromJSON, JSON: ["":""])
    }
}

extension Chargingsites: DataResponse {
    public mutating func mapping(map: Map) {
		allValues = map
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

public protocol Charging {
    var name: String { get }
    var type: String { get }
    var coordinate: CLLocationCoordinate2D { get }
}

public struct DestinationCharging: Charging {
    public var allValues: Map
    public var location: Location = Location()
    public var name: String = ""
    public var type: String = ""
    public var distance_miles: Double = 0
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.lat, longitude: location.long)
    }
    public init() {
        allValues = Map(mappingType: .fromJSON, JSON: ["":""])
    }
}

extension DestinationCharging: DataResponse {
    public mutating func mapping(map: Map) {
        allValues = map
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

public struct Superchargers: Charging{
    public var allValues: Map
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
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.lat, longitude: location.long)
    }
    public init() {
        allValues = Map(mappingType: .fromJSON, JSON: ["":""])
    }
}

extension Superchargers: DataResponse {
    public mutating func mapping(map: Map) {
        allValues = map
        location <- map["location"]
        name <- map["name"]
        type <- map["type"]
        distance_miles <- map["distance_miles"]
        available_stalls <- map["available_stalls"]
        total_stalls <- map["total_stalls"]
        site_closed <- map["site_closed"]
    }
}

