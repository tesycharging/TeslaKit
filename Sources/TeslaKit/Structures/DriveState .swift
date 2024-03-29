//
//  DriveState.swift
//  TeslaKit
//
//  Update by David Lüthi on 14.09.2021
//  based on code from Jaren Hamblin on 11/25/17.
//  Copyright © 2022 David Lüthi. All rights reserved.
//
//


import Foundation
import ObjectMapper
import CoreLocation

/// Response object containing information about the driving and position state of the vehicle
public struct DriveState {
    public var allValues: Map

    ///
    public var shiftState: ShiftState = ShiftState.park

    ///
    public var speed: Int = 0

    ///
    public var longitude: Double = 0

    ///
    public var gpsAsOf: TimeInterval = 0

    ///
    public var power: Int = 0

    ///
    public var latitude: Double = 0

    ///
    public var headingValue: Double = 0

    ///
    public var timestamp: TimeInterval = 0

    ///
    public var nativeLocationSupported: Int = 0

    ///
    public var nativeType: String? = nil

    ///
    public var nativeLongitude: Double? = nil

    ///
    public var nativeLatitude: Double? = nil

    ///
    public var heading: Heading {
        switch Double(self.headingValue) {
        case 0..<22.5: return .north
        case 22.5..<67.5: return .northEast
        case 67.5..<112.5: return .east
        case 112.5..<157.5: return .southEast
        case 157.5..<202.5: return .south
        case 202.5..<247.5: return .southWest
        case 247.5..<292.5: return .west
        case 292.5..<337.5: return .northWest
        case 337.5..<360: return .north
        default: return .north
        }
    }
	
	public var active_route_destination: String = "" 
	public var active_route_energy_at_arrival: Int = 0 
	public var active_route_latitude: Double = 0 
	public var active_route_longitude: Double = 0 
	public var active_route_miles_to_arrival: Double = 0 
	public var active_route_minutes_to_arrival: Double = 0 
	public var active_route_traffic_minutes_delay: Double = 0



    ///
    public init() {
        allValues = Map(mappingType: .fromJSON, JSON: ["":""])
    }
    
    ///
    public func localizedSpeed(distanceUnit: DistanceUnit) -> String {
        if distanceUnit == .imperial {
            return Speed(imperial: self.speed).localizedImperial
        } else {
            return Speed(imperial: self.speed).localizedMetric
        }
    }
    
    public func getPlacemark() async throws -> CLPlacemark {
        return try await CLLocation(latitude: self.latitude, longitude: self.longitude).placemark()
    }
}

extension DriveState: DataResponse {

    public mutating func mapping(map: Map) {
        allValues = map
        gpsAsOf <- map["gps_as_of"]
        headingValue <- map["heading"]
        latitude <- map["latitude"]
        longitude <- map["longitude"]
        power <- map["power"]
        shiftState <- (map["shift_state"], EnumTransform())
        speed <- map["speed"]
        timestamp <- map["timestamp"]
        nativeLocationSupported <- map["native_location_supported"]
        nativeType <- map["native_type"]
        nativeLongitude <- map["native_longitude"]
        nativeLatitude <- map["native_latitude"]
		
		active_route_destination <- map["active_route_destination"] 
		active_route_energy_at_arrival <- map["active_route_energy_at_arrival"]
		active_route_latitude <- map["active_route_latitude"] 
		active_route_longitude <- map["active_route_longitude"]
		active_route_miles_to_arrival <- map["active_route_miles_to_arrival"] 
		active_route_minutes_to_arrival <- map["active_route_miles_to_arrival"] 
		active_route_traffic_minutes_delay <- map["active_route_traffic_minutes_delay"]
    }
}

extension CLLocation {
    public func placemark() async throws -> CLPlacemark {
        let placemarks = try await CLGeocoder().reverseGeocodeLocation(self)
        if placemarks.isEmpty {
            throw NSError()
        } else {
            let placemark = placemarks.first
            if placemark == nil {
                throw NSError()
            } else {
                return placemark!
            }
        }
    }
}
