//
//  VehicleConfig.swift
//  TeslaKit
//
//  Created by Jaren Hamblin on 2/3/18.
//  Copyright © 2018 HamblinSoft. All rights reserved.
//
//  Update by David Lüthi on 17/12/22
//

import Foundation
import ObjectMapper
import SwiftUI

///
public struct VehicleConfig {
    public var allValues: Map
    

    ///
    public var wheelType: String? = nil

    ///
    public var sunRoofInstalled: Int = 0

    ///
    public var trimBadging: String = ""

    ///
    public var seatType: Int = 0

    ///
    public var rearSeatType: Int = 0

    ///
    public var roofColor: String? = nil

    ///
    public var perfConfig: String? = nil

    ///
    public var rhd: Bool = false

    ///
    public var spoilerType: String? = nil

    ///
    public var carSpecialType: String? = nil

    ///
    public var hasLudicrousMode: Bool = false

    ///
    public var timestamp: TimeInterval = 0

    ///
    public var plg: Bool = false

    ///
    public var motorizedChargePort: Bool = false

    ///
    public var euVehicle: Bool = false

    ///
    public var rearSeatHeaters: Int = 0

    ///
    public var thirdRowSeats: String? = nil

    ///
    public var canActuateTrunks: Bool = false

    ///
    public var carType: String? = nil

    ///
    public var chargePortType: String? = nil

    ///
    public var exteriorColor: String? = nil

    ///
    public var canAcceptNavigationRequests: Bool = false
    
    private var color:String = "0,0,0,0,0"
    public var paint_color_override: Color = Color(UIColor(red: 255/255, green: 22/255, blue: 198/255, alpha: 0.9))

    ///
    public init() {
        allValues = Map(mappingType: .fromJSON, JSON: ["":""])
    }
}

extension VehicleConfig: DataResponse {
    public mutating func mapping(map: Map) {
        allValues = map
        canActuateTrunks <- map["can_actuate_trunks"]
        carSpecialType <- map["car_special_type"]
        carType <- map["car_type"]
        chargePortType <- map["charge_port_type"]
        euVehicle <- map["eu_vehicle"]
        exteriorColor <- map["exterior_color"]
        hasLudicrousMode <- map["has_ludicrous_mode"]
        motorizedChargePort <- map["motorized_charge_port"]
        perfConfig <- map["perf_config"]
        plg <- map["plg"]
        rearSeatHeaters <- map["rear_seat_heaters"]
        rearSeatType <- map["rear_seat_type"]
        rhd <- map["rhd"]
        roofColor <- map["roof_color"]
        seatType <- map["seat_type"]
        spoilerType <- map["spoiler_type"]
        sunRoofInstalled <- map["sun_roof_installed"]
        thirdRowSeats <- map["third_row_seats"]
        timestamp <- map["timestamp"]
        trimBadging <- map["trim_badging"]
        wheelType <- map["wheel_type"]
        canAcceptNavigationRequests <- map["can_accept_navigation_requests"]
        color <- map["paint_color_override"]
        let separatedValues = color.components(separatedBy: ",")
        if separatedValues.count > 4 && !(color == "0,0,0,0,0") {
            paint_color_override = Color(UIColor(red: CGFloat((separatedValues[0] as NSString).floatValue)/255, green: CGFloat((separatedValues[1] as NSString).floatValue)/255, blue: CGFloat((separatedValues[2] as NSString).floatValue)/255, alpha: CGFloat((separatedValues[3] as NSString).floatValue)))
        } else {
            paint_color_override = Color(UIColor(red: 255/255, green: 22/255, blue: 198/255, alpha: 0.9))
        }
    }
}


//{
//    "plg" : true,
//    "spoiler_type" : "None",
//    "motorized_charge_port" : true,
//    "can_actuate_trunks" : false,
//    "eu_vehicle" : false,
//    "rear_seat_heaters" : 0,
//    "rear_seat_type" : 0,
//    "third_row_seats" : "None",
//    "car_special_type" : "base",
//    "timestamp" : 1516240723415,
//    "car_type" : "models2",
//    "charge_port_type" : "US",
//    "sun_roof_installed" : 0,
//    "wheel_type" : "AeroTurbine19",
//    "exterior_color" : "Black",
//    "perf_config" : "P2",
//    "trim_badging" : "75",
//    "roof_color" : "Glass",
//    "seat_type" : 2,
//    "rhd" : false,
//    "has_ludicrous_mode" : false
//}


