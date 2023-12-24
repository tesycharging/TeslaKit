//
//  LocationData.swift
//  TeslaKit
//
//  Created by David Lüthi on 10.06.2021
//  Copyright © 2023 David Lüthi. All rights reserved.
//


import Foundation
import ObjectMapper

/// Response object containing information about the charge state of the vehicle
public struct EndpointData {
    public var allValues: Map
	
	 /// The unique identifier of the vehicle
    public var id: String = ""

    /// The unique identifier of the vehicle (use id)
    public var vehicleId: Int = 0

    /// The unique identifier of the user of the vehicle
    public var userId: Int = 0
	
	 /// The vehicle's vehicle identification number
    public var vin: VIN?
	
	public var tokens: [String] = []
	
	public var inService: Bool = false
	 
	public var status: VehicleStatus = VehicleStatus.asleep
	
	public var color: String = ""  
	public var access_type: String = ""  
	public var OWNER: String = ""  
	public var granular_access: [String] = []
	public var calendar_enabled: Bool = false 
	public var api_version: Int = 0 
	public var backseat_token: String = "" 
	public var backseat_token_updated_at: String = ""
	public var ble_autopair_enrolled: Bool = false 

    public var chargeState = ChargeState()
    public var climateState = ClimateState()
    public var driveState = DriveState()
    public var guiSettings = GUISettings()
    public var vehicleConfig = VehicleConfig()
    public var vehicleState = VehicleState()
	
	public init() {
        allValues = Map(mappingType: .fromJSON, JSON: ["":""])
    }
	
}

@available(macOS 13.1, *)
extension EndpointData: DataResponse {
    public mutating func mapping(map: Map) {
        allValues = map
        let isLocationData: Bool = !(map.JSON["id_s"] is String)
        if isLocationData {
            id <- map["response.id_s"]
            userId <- map["response.user_id"]
            vehicleId <- map["response.vehicle_id"]
            vin <- (map["response.vin"], VINTransform())
            status <- (map["response.state"], EnumTransform())
            tokens <- map["response.tokens"]
			inService <- map["response.in_service"]
            
            chargeState <-  map["response.charge_state"]
            climateState <-  map["response.climate_state"]
            driveState  <- map["response.drive_state"]
            guiSettings <-  map["response.gui_settings"]
            vehicleConfig <-  map["response.vehicle_config"]
            vehicleState <-  map["response.vehicle_state"]
			
			color <- map["response.color"]
			access_type <- map["response.access_type"]
			OWNER <- map["response.OWNER"]
			granular_access <- map["response.granular_access"]
			calendar_enabled <- map["response.calendar_enabled"] 
			api_version <- map["response.api_version"] 
			backseat_token <- map["response.backseat_token"]
			backseat_token_updated_at <- map["response.backseat_token_updated_at"]
			ble_autopair_enrolled <- map["response.ble_autopair_enrolled"] 
        } else {
            id <- map["id_s"]
            userId <- map["user_id"]
            vehicleId <- map["vehicle_id"]
            vin <- (map["vin"], VINTransform())
            status <- (map["state"], EnumTransform())
            tokens <- map["tokens"]
        }
    }
}
