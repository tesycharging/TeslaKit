//
//  OptionCodes.swift
//  TeslaKit
//
//  Copyright © 2022 David Lüthi. All rights reserved.
//

import Foundation
import ObjectMapper
import MapKit

public struct OptionCodes {
    public var codes: [OptionCode] = []
    public init() {}
    public init(codes: [OptionCode]) {
        self.codes = codes
    }
}

extension OptionCodes: Mappable {
    public mutating func mapping(map: Map) {
        codes <- map["codes"]
    }
}

public struct OptionCode {
    public var allValues: Map
    public var code: String = ""
    public var colorCode: String = ""
    public var displayName: String = ""
    public var isActive: Bool = false
    public init() {
        allValues = Map(mappingType: .fromJSON, JSON: ["":""])
    }
}

extension OptionCode: DataResponse {
    public mutating func mapping(map: Map) {
        allValues = map
        code <- map["code"]
        colorCode <- map["colorCode"]
        displayName <- map["displayName"]
        isActive <- map["isActive"]
    }
}

extension OptionCode: Hashable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.code == rhs.code
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(code)
    }
}
