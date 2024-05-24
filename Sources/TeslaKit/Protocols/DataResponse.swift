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
    private func iteratingThroughDictionary(i: Int, key: String, value: NSDictionary, childStructs: Bool) -> [VehicleAllData] {
        var result = [VehicleAllData]()
        var j = i
        for (k1, v1) in (value) {
            var p = ""
            if key != "response" {
                p = "   "+key.replacingOccurrences(of: "_", with: " ")+"."
            }
            var v11 = v1
            if (v1 is NSDictionary) {
                v11 = "{..}"
            }
            result.append(VehicleAllData(p+(k1 as! String).replacingOccurrences(of: "_", with: " "), "\(v11)", j % 2 == 0))
            j = j + 1
        }
        return result
    }
    
    public func values(childStructs: Bool = true) -> [VehicleAllData] {
        var result = [VehicleAllData]()
        let map = allValues.JSON.sorted{ (first, second) -> Bool in
            return first.key < second.key
        }
        var i = 0
        for (k, v) in map {
            if (v is NSDictionary) && childStructs {
                result.append(contentsOf: iteratingThroughDictionary(i: i, key: k, value: v as! NSDictionary, childStructs: childStructs))
            } else if (v is NSArray) {
                var j = 0
                for v1 in (v as! NSArray) {
                    if (v1 is NSDictionary) {
                        result.append(contentsOf: iteratingThroughDictionary(i: i, key: k + "[\(j)]", value: v1 as! NSDictionary, childStructs: childStructs))
                    }
                    j = j + 1
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
