//
//  DistanceUnit.swift
//  TeslaKit
//
//  Update by David Lüthi on 10.06.2021
//  based on code from Jaren Hamblin on 2/3/18.
//  Copyright © 2022 David Lüthi. All rights reserved.
//

import Foundation

///
public enum DistanceUnit: String, CustomStringConvertible {

    ///
    case imperial = "mi/hr"

    ///
    case metric = "km/hr"

    ///
    public var description: String {
        switch self {
        case .imperial:
            return "Imperial (MPH)"
        case .metric:
            return "Metric (KPH)"
        }
    }
    
    public var speedUnit: String {
        return self.rawValue
    }
    
    public var distanceUnit: String {
        switch self {
        case .imperial:
            return "mi"
        case .metric:
            return "km"
        }
    }
}
