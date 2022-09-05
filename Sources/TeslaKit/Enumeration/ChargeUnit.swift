//
//  ChargeUnit.swift
//  TeslaKit
//
//  Update by David Lüthi on 10.06.2021
//  based on code from Jaren Hamblin on 2/3/18.
//  Copyright © 2022 David Lüthi. All rights reserved.
//

import Foundation

/// The charge unit selected within the UI of the vehicle. Can me in miles per hour or kilometers per hour.
public enum ChargeUnit: String, CustomStringConvertible {

    ///
    case imperial = "mi/hr"

    ///
    case metric = "km/hr"

    ///
    case power = "kW"
        
    ///
    case capacity = "kWh"

    ///
    public var description: String {
        switch self {
        case .imperial:
            return "Imperial (MPH)"
        case .metric:
            return "Metric (KPH)"
        case .power:
            return "kW"
        case .capacity:
            return "kWh"
        }
    }
}
