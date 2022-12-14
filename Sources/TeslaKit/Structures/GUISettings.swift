//
//  GUISettings.swift
//  TeslaKit
//
//  Update by David Lüthi on 10.06.2021
//  based on code from Jaren Hamblin on 11/25/17.
//  Copyright © 2022 David Lüthi. All rights reserved.
//



import Foundation
import ObjectMapper

/// Returns various information about the GUI settings of the car, such as unit format and range display.
public struct GUISettings {
    public var allValues: Map
    
    /// Distance units (mi/hr)
    public var distanceUnits: DistanceUnit = DistanceUnit.metric

    /// Charge Rate units (mi/hr)
    public var chargeRateUnits: ChargeUnit = ChargeUnit.power

    /// Temperature Units (F)
    public var temperatureUnits: TemperatureUnit = TemperatureUnit.celsius

    /// Indicates whether 24 hour time or 12 hour time is selected
    public var is24HourTime: Bool = false

    /// Range display time (Rated)
    public var rangeDisplay: RangeDisplay = RangeDisplay.rated

    /// Timestamp
    public var timestamp: TimeInterval = 0

    ///
    public var temperatureUnitsIsFahrenheit: Bool { return self.temperatureUnits == .fahrenheit }

    ///
    public init() {
        allValues = Map(mappingType: .fromJSON, JSON: ["":""])
    }
}

extension GUISettings: DataResponse {

    public mutating func mapping(map: Map) {
        allValues = map
        chargeRateUnits <- (map["gui_charge_rate_units"], EnumTransform())
        is24HourTime <- map["gui_24_hour_time"]
        rangeDisplay <- (map["gui_range_display"], EnumTransform())
        temperatureUnits <- (map["gui_temperature_units"], EnumTransform())
        timestamp <- map["timestamp"]
        distanceUnits <- (map["gui_distance_units"], EnumTransform())
    }
}

//{
//    "gui_distance_units" : "mi\/hr",
//    "gui_charge_rate_units" : "mi\/hr",
//    "timestamp" : 1513809818903,
//    "gui_temperature_units" : "F",
//    "gui_24_hour_time" : false,
//    "gui_range_display" : "Rated"
//}
