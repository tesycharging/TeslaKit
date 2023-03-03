//
//  DataResponse.swift
//  TeslaKit
//
//  Update by David Lüthi on 10.06.2021
//  based on code from Jaren Hamblin on 11/25/17.
//  Copyright © 2022 David Lüthi. All rights reserved.
//


import Foundation
import ObjectMapper

///
public protocol DataResponse: Mappable {
    var allValues: Map { get }
}

extension DataResponse {
    public func values(childStructs: Bool = true) -> [VehicleAllData] {
        var result = [VehicleAllData]()
        let map = allValues.JSON.sorted{ (first, second) -> Bool in
            return first.key < second.key
        }
        var i = 0
        for (k, v) in map {
            if (v is NSDictionary) && childStructs {
                for (k1, v1) in (v as! NSDictionary) {
                    var p = ""
                    if k != "response" {
                        p = "   "+k.replacingOccurrences(of: "_", with: " ")+"."
                    }
                    var v11 = v1
                    if (v1 is NSDictionary) {
                        v11 = "{..}"
                    }
                    result.append(VehicleAllData(p+(k1 as! String).replacingOccurrences(of: "_", with: " "), "\(v11)", i % 2 == 0))
                    i = i + 1
                }
            } else {
                result.append(VehicleAllData(k.replacingOccurrences(of: "_", with: " "), "\(v)", i % 2 == 0))
                i = i + 1
            }
        }
        return result
    }
}

public struct VehicleAllData: Identifiable {
    public var id = UUID()
    public var key: String
    public var value: String
    public var odd: Bool
    
    public init(_ key: String, _ value: String, _ odd: Bool) {
        self.key = key
        self.value = value
        self.odd = odd // just for nice display purposes
    }
}
