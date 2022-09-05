//
//  KindOfVehicle.swift
//  TeslaKit
//
//  Created by David Lüthi on 14.08.22
//  Copyright © 2022 David Lüthi. All rights reserved.
//

import Foundation

public enum KindOfVehicle: String, CustomStringConvertible, Decodable,  CaseIterable {
    case novehicle = "no vehicle"
    case demovehicle = "demo vehicle"
    case ledgitVehicle = "ledgit vehicle"
    
    public var description: String {
        get {
            return self.rawValue
        }
    }
}
