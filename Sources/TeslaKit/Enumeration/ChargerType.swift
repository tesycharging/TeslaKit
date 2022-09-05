//
//  ChargerType.swift
//  TeslaKit
//
//  Created by David Lüthi on 14.08.22.
//  Copyright © 2022 David Lüthi. All rights reserved.
//

import Foundation

public enum ChargerType: String, CustomStringConvertible, Decodable,  CaseIterable {
    case chargingTCS = "TCS"
    case chargingCCS = "CCS"
    case charging230V = "230V"
    case charging360V = "360V"
    case chargingQ = "unknown"
    case none = "none"
   
    public var description: String {
        get {
            return self.rawValue
        }
    }
    
    public static var values: [String] {
        ChargerType.allCases.map { $0.rawValue }
    }
    
    public static func toType(type: String) -> ChargerType{
        ChargerType(rawValue: type) ?? .none
    }
}
