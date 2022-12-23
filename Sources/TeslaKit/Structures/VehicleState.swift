//
//  VehicleState.swift
//  TeslaKit
//
//  Update by David Lüthi on 10.06.2021
//  based on code from Jaren Hamblin on 11/25/17.
//  Copyright © 2022 David Lüthi. All rights reserved.
//


import Foundation
import ObjectMapper

///
public struct VehicleState {
    public var allValues: Map

    ///
    public var exteriorColor: String?

    ///
    public var centerDisplayState: Int = 0

    ///
    public var autoparkStyle: String? = nil

    /// Returns whether remote start is active (Driver can begin keyless driving by entering the car, pressing the brake, and selecting Drive)
    public var remoteStart: Bool = false

    ///
    public var odometer: Double = 0

    ///
    public var rearTrunkState: Int = 0

    ///
    public var sunRoofPercentOpen: Int = 0

    ///
    public var vehicleName: String? = nil

    ///
    public var remoteStartSupported: Bool = false

    ///
    public var darkRims: Bool = false

    ///
    public var locked: Bool = false

    ///
    public var rearSeatType: Int = 0

    ///
    public var rhd: Bool = false

    ///
    public var autoparkStateV2: String? = nil

    ///
    public var roofColor: String? = nil

    ///
    public var rearSeatHeaters: Int = 0

    /// Returns whether valet mode is current enabled
    public var valetMode: Bool = false

    ///
    public var parsedCalendarSupported: Bool = false

    ///
    public var apiVersion: Int = 0

    ///
    public var homelinkdevicecount: Int = 0
    
    ///
    public var homelinkNearby: Bool = false

    ///
    public var autoparkState: String? = nil

    ///
    public var lastAutoparkError: String? = nil

    ///
    public var driverRearDoorState: Int = 0

    ///
    public var hasSpoiler: Bool = false

    ///
    public var calendarSupported: Bool = false

    ///
    public var sunRoofState: String? = nil

    ///
    public var driverFrontDoorState: Int = 0

    /// Returns whether valet mode requires PIN
    public var valetPinNeeded: Bool = false

    ///
    public var passengerRearDoorState: Int = 0

    ///
    public var spoilerType: String? = nil

    ///
    public var carType: String? = nil

    ///
    public var perfConfig: String? = nil

    ///
    public var carVersion: String? = nil

    ///
    public var seatType: Int = 0

    ///
    public var thirdRowSeats: String? = nil

    ///
    public var frontTrunkState: Int = 0

    ///
    public var notificationsSupported: Bool = false

    ///
    public var passengerFrontDoorState: Int = 0

    ///
    public var wheelType: String? = nil

    ///
    public var sunRoofInstalled: Int = 0

    ///
    public var timestamp: TimeInterval = 0

    ///
    public var isUserPresent: Bool = false

    /// Indicates whether sentry mode is activated
    public var sentryMode: Bool = false

    ///
    public var speedLimitMode: SpeedLimitMode = SpeedLimitMode()

    ///
    public var softwareUpdate: SoftwareUpdate = SoftwareUpdate()

    ///
    public var mediaState: MediaState = MediaState()

    ///
    public init() {
        allValues = Map(mappingType: .fromJSON, JSON: ["":""])
    }

    ///
    public var isRearTrunkOpen: Bool { return rearTrunkState != 0 }

    ///
    public var isFrontTrunkOpen: Bool { return frontTrunkState != 0 }

    ///
    public var isDriverFrontDoorOpen: Bool { return driverFrontDoorState != 0 }

    ///
    public var isDriverRearDoorOpen: Bool { return driverRearDoorState != 0 }

    ///
    public var isPassengerFrontDoorOpen: Bool { return passengerFrontDoorState != 0 }

    ///
    public var isPassengerRearDoorOpen: Bool { return passengerRearDoorState != 0 }
    
    ///
    public var rd_window: Int = 0
    ///
    public var rp_window: Int = 0
    ///
    public var fd_window: Int = 0
    ///
    public var fp_window: Int = 0
    
    ///
    public var isDriverFrontWindowOpen: Bool { return fd_window != 0 }

    ///
    public var isDriverRearWindowOpen: Bool { return rd_window != 0 }

    ///
    public var isPassengerFrontWindowOpen: Bool { return fp_window != 0 }

    ///
    public var isPassengerRearWindowOpen: Bool { return rp_window != 0 }

    public var tpms_last_seen_pressure_time_fl: TimeInterval = 0
    public var tpms_last_seen_pressure_time_fr: TimeInterval = 0
    public var tpms_last_seen_pressure_time_rl: TimeInterval = 0
    public var tpms_last_seen_pressure_time_rr: TimeInterval = 0
    
    public var tpms_pressure_fl: Double = 0
    public var tpms_pressure_fr: Double = 0
    public var tpms_pressure_rl: Double = 0
    public var tpms_pressure_rr: Double = 0
    
    public var tpms_hard_warning_fl: Int = 0
    public var tpms_hard_warning_fr: Int = 0
    public var tpms_hard_warning_rl: Int = 0
    public var tpms_hard_warning_rr: Int = 0
    
    public var tpms_soft_warning_fl: Int = 0
    public var tpms_soft_warning_fr: Int = 0
    public var tpms_soft_warning_rl: Int = 0
    public var tpms_soft_warning_rr: Int = 0
    
    public var tpms_h_warning_fl: Bool { return tpms_hard_warning_fl != 0 }
    public var tpms_h_warning_fr: Bool { return tpms_hard_warning_fr != 0 }
    public var tpms_h_warning_rl: Bool { return tpms_hard_warning_rl != 0 }
    public var tpms_h_warning_rr: Bool { return tpms_hard_warning_rr != 0 }
    
    public var tpms_s_warning_fl: Bool { return tpms_soft_warning_fl != 0 }
    public var tpms_s_warning_fr: Bool { return tpms_soft_warning_fr != 0 }
    public var tpms_s_warning_rl: Bool { return tpms_soft_warning_rl != 0 }
    public var tpms_s_warning_rr: Bool { return tpms_soft_warning_rr != 0 }
}

extension VehicleState: DataResponse {

    public mutating func mapping(map: Map) {
        allValues = map
        apiVersion <- map["api_version"]
        autoparkState <- map["autopark_state"]
        autoparkStateV2 <- map["autopark_state_v2"]
        autoparkStyle <- map["autopark_style"]
        calendarSupported <- map["calendar_supported"]
        carType <- map["car_type"]
        carVersion <- map["car_version"]
        centerDisplayState <- map["center_display_state"]
        darkRims <- map["dark_rims"]
        driverFrontDoorState <- map["df"]
        driverRearDoorState <- map["dr"]
        exteriorColor <- map["exterior_color"]
        frontTrunkState <- map["ft"]
        hasSpoiler <- map["has_spoiler"]
        homelinkdevicecount <- map ["homelink_device_count"]
        homelinkNearby <- map["homelink_nearby"]
        lastAutoparkError <- map["last_autopark_error"]
        notificationsSupported <- map["notifications_supported"]
        odometer <- map["odometer"]
        parsedCalendarSupported <- map["parsed_calendar_supported"]
        passengerFrontDoorState <- map["pf"]
        passengerRearDoorState <- map["pr"]
        perfConfig <- map["perf_config"]
        rearSeatHeaters <- map["rear_seat_heaters"]
        rearSeatType <- map["rear_seat_type"]
        rearTrunkState <- map["rt"]
        remoteStart <- map["remote_start"]
        remoteStartSupported <- map["remote_start_supported"]
        rhd <- map["rhd"]
        roofColor <- map["roof_color"]
        seatType <- map["seat_type"]
        spoilerType <- map["spoiler_type"]
        sunRoofInstalled <- map["sun_roof_installed"]
        sunRoofPercentOpen <- map["sun_roof_percent_open"]
        sunRoofState <- map["sun_roof_state"]
        thirdRowSeats <- map["third_row_seats"]
        timestamp <- map["timestamp"]
        valetMode <- map["valet_mode"]
        valetPinNeeded <- map["valet_pin_needed"]
        vehicleName <- map["vehicle_name"]
        wheelType <- map["wheel_type"]
        locked <- map["locked"]
        isUserPresent <- map["is_user_present"]
        speedLimitMode <- map["speed_limit_mode"]
        softwareUpdate <- map["software_update"]
        mediaState <- map["media_state"]
        sentryMode <- map["sentry_mode"]
        
        rd_window <- map["rd_window"]
        rp_window <- map["rp_window"]
        fd_window <- map["fd_window"]
        fp_window <- map["fp_window"]
        
        tpms_last_seen_pressure_time_fl <- map["tpms_last_seen_pressure_time_fl"]
        tpms_last_seen_pressure_time_fr <- map["tpms_last_seen_pressure_time_fr"]
        tpms_last_seen_pressure_time_rl <- map["tpms_last_seen_pressure_time_rl"]
        tpms_last_seen_pressure_time_rr <- map["tpms_last_seen_pressure_time_rr"]
        
        tpms_pressure_fl <- map["tpms_pressure_fl"]
        tpms_pressure_fr <- map["tpms_pressure_fr"]
        tpms_pressure_rl <- map["tpms_pressure_rl"]
        tpms_pressure_rr <- map["tpms_pressure_rr"]
        
        tpms_hard_warning_fl <- map["tpms_hard_warning_fl"]
        tpms_hard_warning_fr <- map["tpms_hard_warning_fr"]
        tpms_hard_warning_rl <- map["tpms_hard_warning_rl"]
        tpms_hard_warning_rr <- map["tpms_hard_warning_rr"]
        
        tpms_soft_warning_fl <- map["tpms_soft_warning_fl"]
        tpms_soft_warning_fr <- map["tpms_soft_warning_fr"]
        tpms_soft_warning_rl <- map["tpms_soft_warning_rl"]
        tpms_soft_warning_rr <- map["tpms_soft_warning_rr"]
    }
}

extension VehicleState {
    public func localizedOdometer(distanceUnit: DistanceUnit) -> String {
        if distanceUnit == .metric {
            return Distance(imperial: odometer).localizedMetric
        } else {
            return Distance(imperial: odometer).localizedImperial
        }
    }
}

//{
//    "exterior_color" : "Black",
//    "center_display_state" : 0,
//    "autopark_style" : "dead_man",
//    "remote_start" : false,
//    "odometer" : 1300.683614,
//    "rt" : 0,
//    "sun_roof_percent_open" : 0,
//    "vehicle_name" : "Darth",
//    "remote_start_supported" : true,
//    "dark_rims" : false,
//    "locked" : true,
//    "rear_seat_type" : 0,
//    "rhd" : false,
//    "autopark_state_v2" : "disabled",
//    "roof_color" : "Glass",
//    "rear_seat_heaters" : 0,
//    "valet_mode" : false,
//    "parsed_calendar_supported" : true,
//    "api_version" : 3,
//    "homelink_nearby" : false,
//    "autopark_state" : "unavailable",
//    "last_autopark_error" : "no_error",
//    "dr" : 0,
//    "has_spoiler" : false,
//    "calendar_supported" : true,
//    "sun_roof_state" : "unknown",
//    "df" : 0,
//    "valet_pin_needed" : true,
//    "pr" : 0,
//    "spoiler_type" : "None",
//    "car_type" : "models2",
//    "perf_config" : "P2",
//    "car_version" : "2017.44 02fdc86",
//    "seat_type" : 2,
//    "third_row_seats" : "None",
//    "ft" : 0,
//    "notifications_supported" : true,
//    "pf" : 0,
//    "wheel_type" : "AeroTurbine19",
//    "sun_roof_installed" : 0,
//    "timestamp" : 1513809833025
//}



