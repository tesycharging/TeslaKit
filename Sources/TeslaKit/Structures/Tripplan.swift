//
//  Tripplan.swift
//  
//
//  Created by David Lüthi on 24.08.23.
//

import Foundation
import ObjectMapper

public struct Tripplan: TKMappable {
    public var allValues: Map
  
    public var polylines: String = ""
    
    public var destination_soe: Double = 0.1

    public var origin_soe: Double = 0.8

    public var status: String = "TRIP_PLAN_FAILURE_NOT_POSSIBLE" // TRIP_PLAN_SUCCESS_DIRECT, TRIP_PLAN_SUCCESS_WITH_STOPS

    public var total_drive_mi: Double = 0

    public var total_drive_kWh: Double = 0

    public var total_charge_dur_s: Double = 0

    public var total_charge_kWh: Double = 0

    public var stops: [ChargingStop] = []

    public var error_message: String = "error no path found"

    ///
    public init() {
        allValues = Map(mappingType: .fromJSON, JSON: ["":""])
    }
}

@available(macOS 13.1, *)
extension Tripplan: DataResponse {
    public mutating func mapping(map: Map) {
        allValues = map
        status <- map["status"]
        if status == "TRIP_PLAN_FAILURE_NOT_POSSIBLE" {
            error_message <- (map["error_message"])
        } else {
            polylines <- (map["polylines"])
            destination_soe <- map["destination_soe"]
            origin_soe <- (map["origin_soe"])            
            total_drive_mi <- (map["total_drive_mi"])
            if status == "TRIP_PLAN_SUCCESS_WITH_STOPS" {
              total_drive_kWh <- map["total_drive_kWh"]
              total_charge_dur_s <- (map["total_charge_dur_s"])
              total_charge_kWh <- map["total_charge_kWh"]
              stops <- map["stops"]
            }
        }
    }
}

public struct ChargingStop {
    public var allValues: Map
    public var id: String = ""
    public var trt_id: String = ""
    public var name: String = ""
    public var location: ChargingLocation = ChargingLocation() 
    public var addr: String = ""
    public var arrival_soe: Double = 0
    public var charge_dur_s: Double = 0
    public var departure_soe: Double = 0
    public var stop_type: String = ""
    public var drive_dur_s: Double = 0
    public var drive_distance_m: Double = 0
    public var max_power: Double = 0
}

extension ChargingStop: DataResponse {
    public mutating func mapping(map: Map) {
        allValues = map
        id <- map["id"]
        trt_id <- map["trt_id"]
        name <- map["name"]
        location <- map["location"] 
        addr <- map["addr"]
        arrival_soe <- map["arrival_soe"]
        charge_dur_s <- map["charge_dur_s"]
        departure_soe <- map["departure_soe"]
        stop_type <- map["stop_type"]
        drive_dur_s <- map["drive_dur_s"]
        drive_distance_m <- map["drive_distance_m"]
        max_power <- map["max_power"]
    }
}

public struct ChargingLocation: TKMappable {
    public var lat: Double = 0
    public var lng: Double = 0
    public init() {}
}

extension ChargingLocation {
    public mutating func mapping(map: Map) {
        lat <- map["lat"]
        lng <- map["lng"]
    }
}
