//
//  SetClimateMode.swift
//  TeslaKit
//
//  Created by David Lüthi on 19.12.22.
//  Copyright © 2022 David Lüthi. All rights reserved.
//

import Foundation
import ObjectMapper

public enum ClimateMode: String {
	case off = "Off"
	case on = "On"
    case dog = "Dog Mode"
	case camp = "Camp Mode"
	
	public var toNumber: Int {
		switch(self) {
		case .off: return 0
		case .on: return 1
		case .dog: return 2
		case .camp: return 3
		}
	}
}

/// Set the temperature target for the HVAC system.
public struct SetClimateMode {

    public var climate_keeper_mode : Int = 1

    ///
    public init() {}

    public init(mode: ClimateMode) {
        self.climate_keeper_mode = mode.toNumber
    }
}

extension SetClimateMode: Mappable {
    public mutating func mapping(map: Map) {
		print(map)
        climate_keeper_mode <- map["climate_keeper_mode"]
    }
}
