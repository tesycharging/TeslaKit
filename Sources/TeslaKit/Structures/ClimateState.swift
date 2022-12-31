//
//  ClimateState.swift
//  TeslaKit
//
//  Update by David Lüthi on 10.06.2021
//  based on code from Jaren Hamblin on 11/25/17.
//  Copyright © 2022 David Lüthi. All rights reserved.
//


import Foundation
import ObjectMapper

/// Response object containing information about the current temperature and climate control state of a vehicle
public struct ClimateState {
    public var allValues: Map
    
    ///
    public var seatHeaterLeft: Int = 0

    ///
    public var fanStatus: Int = 0

    ///
    public var isFrontDefrosterOn: Bool = false

    ///
    public var isRearDefrosterOn: Bool = false

    ///
    public var isClimateOn: Bool = false
    
    ///
    public var isDefrostMode: Bool { !(defrostMode == 0) }
    
    public var defrostMode: Int = 0

    ///
    public var seatHeaterRearLeft: Int = 0

    ///
    public var minimumAvailableTemperature: Double = 0

    ///
    public var insideTemperature: Double? = nil

    ///
    public var driverTemperatureSetting: Double = 0

    ///
    public var passengerTemperatureSetting: Double = 0

    ///
    public var outsideTemperature: Double? = nil

    ///
    public var seatHeaterRearCenter: Int = 0

    ///
    public var timestamp: TimeInterval = 0

    ///
    public var rightTemperatureDirection: Int? = nil

    ///
    public var leftTemperatureDirection: Int? = nil

    ///
    public var seatHeaterRearRight: Int = 0

    ///
    public var seatHeaterRearRightBack: Int = 0

    ///
    public var seatHeaterRight: Int = 0

    ///
    public var seatHeaterRearLeftBack: Int = 0

    ///
    public var smartPreconditioning: Bool = false

    ///
    public var maximumAvailableTemperature: Double = 0

    ///
    public var isAutoConditioningOn: Int = 0

    ///
    public var isPreconditioning: Int = 0

    ///
    public var sideMirrorHeaters: Int = 0

    ///
    public var batteryHeaterNoPower: Int = 0

    ///
    public var steeringWheelHeater: Int = 0

    ///
    public var batteryHeater: Int = 0

    ///
    public var wiperBladeHeater: Int = 0

    ///
    public var auto_seat_climate_left: Int = 0
    
    ///
    public var auto_seat_climate_right: Int = 0
    
    public init() {
        allValues = Map(mappingType: .fromJSON, JSON: ["":""])
    }
}

extension ClimateState: DataResponse {

    public mutating func mapping(map: Map) {
        allValues = map
        driverTemperatureSetting <- map["driver_temp_setting"]
        fanStatus <- map["fan_status"]
        insideTemperature <- map["inside_temp"]
        isAutoConditioningOn <- map["is_auto_conditioning_on"]
        isClimateOn <- map["is_climate_on"]
        defrostMode <- map["defrost_mode"]
        isFrontDefrosterOn <- map["is_front_defroster_on"]
        isRearDefrosterOn <- map["is_rear_defroster_on"]
        leftTemperatureDirection <- map["left_temp_direction"]
        maximumAvailableTemperature <- map["max_avail_temp"]
        minimumAvailableTemperature <- map["min_avail_temp"]
        minimumAvailableTemperature <- map["min_avail_temp"]
        outsideTemperature <- map["outside_temp"]
        passengerTemperatureSetting <- map["passenger_temp_setting"]
        rightTemperatureDirection <- map["right_temp_direction"]
        seatHeaterRearCenter <- map["seat_heater_rear_center"]
        seatHeaterRearLeft <- map["seat_heater_rear_left"]
        seatHeaterRearLeftBack <- map["seat_heater_rear_left_back"]
        seatHeaterRearRight <- map["seat_heater_rear_right"]
        seatHeaterRearRightBack <- map["seat_heater_rear_right_back"]
        seatHeaterRight <- map["seat_heater_right"]
        smartPreconditioning <- map["smart_preconditioning"]
        timestamp <- map["timestamp"]
        seatHeaterLeft <- map["seat_heater_left"]
        isPreconditioning <- map["is_preconditioning"]
        sideMirrorHeaters <- map["side_mirror_heaters"]
        batteryHeaterNoPower <- map["battery_heater_no_power"]
        steeringWheelHeater <- map["steering_wheel_heater"]
        batteryHeater <- map["battery_heater"]
        wiperBladeHeater <- map["wiper_blade_heater"]
        auto_seat_climate_left <- map["auto_seat_climate_left"]
        auto_seat_climate_right <- map["auto_seat_climate_right"]
    }
}

extension ClimateState {
    public func localizedInsideTemperature(temperatureUnits: TemperatureUnit) -> String {
        if temperatureUnits == .celsius {
            return Temperature(celsius: self.insideTemperature ?? 0).localizedCelsius
        } else {
            return Temperature(celsius: self.insideTemperature ?? 0).localizedFahrenheit
        }
    }
    
    public func localizedOutsideTemperature(temperatureUnits: TemperatureUnit) -> String {
        if temperatureUnits == .celsius {
            return Temperature(celsius: self.outsideTemperature ?? 0).localizedCelsius
        } else {
            return Temperature(celsius: self.outsideTemperature ?? 0).localizedFahrenheit
        }
    }
}

//{
//    "seat_heater_left" : 1,
//    "fan_status" : 0,
//    "is_front_defroster_on" : false,
//    "is_rear_defroster_on" : false,
//    "is_climate_on" : false,
//    "seat_heater_rear_left" : 0,
//    "min_avail_temp" : 15,
//    "inside_temp" : null,
//    "driver_temp_setting" : 22.199999999999999,
//    "passenger_temp_setting" : 22.199999999999999,
//    "outside_temp" : null,
//    "seat_heater_rear_center" : 0,
//    "timestamp" : 1513809833025,
//    "right_temp_direction" : null,
//    "left_temp_direction" : null,
//    "seat_heater_rear_right" : 0,
//    "seat_heater_rear_right_back" : 0,
//    "seat_heater_right" : 0,
//    "seat_heater_rear_left_back" : 0,
//    "smart_preconditioning" : false,
//    "max_avail_temp" : 28,
//    "is_auto_conditioning_on" : null
//}

