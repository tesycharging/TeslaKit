//
//  ChargeUnit.swift
//  Tests
//
//  Created by Jaren Hamblin on 2/3/18.
//  Copyright © 2018 HamblinSoft. All rights reserved.
//
//  Updated by David Lüthi on 14(09/22
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
