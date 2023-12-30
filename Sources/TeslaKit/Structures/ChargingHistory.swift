//
//  ChargingHistory.swift
//  TeslaKit
//
//  Copyright © 2022 David Lüthi. All rights reserved.
//

import Foundation
import ObjectMapper
import MapKit

public struct ChargingHistory {
    public var data: [ChargingSession] = []
    public init() {}
    public init(data: [ChargingSession]) {
        self.data = data
    }
}

extension ChargingHistory: Mappable {
    public mutating func mapping(map: Map) {
        data <- map["data"]
        
    }
}

public struct ChargingSession {
    public var allValues: Map
    public var sessionId: Int = 0
    public var vin: String = ""
    public var siteLocationName: String = ""
    public var chargeStartDateTime: String = ""
    public var chargeStopDateTime: String = ""
    public var unlatchDateTime: String = ""
    public var countryCode: String = ""
    public var fees: [String] = []
    public var billingType: String = ""
    public var invoices: [String] = []
    public var vehicleMakeType: String = ""
    public init() {
        allValues = Map(mappingType: .fromJSON, JSON: ["":""])
    }
}

extension ChargingSession: DataResponse {
    public mutating func mapping(map: Map) {
        allValues = map
        sessionId <- map["sessionId"]
        vin <- map["vin"]
        siteLocationName <- map["siteLocationName"]
        chargeStartDateTime <- map["chargeStartDateTime"]
        chargeStopDateTime <- map["chargeStopDateTime"]
        unlatchDateTime <- map["unlatchDateTime"]
        countryCode <- map["countryCode"]
        fees <- map["fees"]
        billingType <- map["billingType"]
        invoices <- map["invoices"]
        vehicleMakeType <- map["vehicleMakeType"]
    }
}

extension ChargingSession: Hashable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.sessionId == rhs.sessionId
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(sessionId)
    }
}
