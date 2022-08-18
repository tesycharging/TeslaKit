//
//  KindOfVehicle.swift
//  Tesy
//
//  Created by David Lüthi on 14.08.22.
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
