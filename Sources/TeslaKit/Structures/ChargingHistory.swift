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

public struct ChargingSession: Identifiable {
    public let id = UUID()
    public var allValues: Map
    public var sessionId: Int = 0
    public var vin: String = ""
    public var siteLocationName: String = ""
    public var chargeStartDateTime: Date?
    public var chargeStopDateTime: Date?
    public var unlatchDateTime: Date?
    public var countryCode: String = ""
    public var fees: [ChargingFees] = []
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
        let dateFormatter = ISO8601DateFormatter()
        var chargeStartDate: String = ""
        chargeStartDate <- map["chargeStartDateTime"]
        var chargeStopDate: String = ""
        chargeStopDate <- map["chargeStopDateTime"]
        var unlatchDate: String = ""
        unlatchDate <- map["unlatchDateTime"]
        chargeStartDateTime = dateFormatter.date(from: chargeStartDate)
        chargeStopDateTime = dateFormatter.date(from: chargeStopDate)
        unlatchDateTime = dateFormatter.date(from: unlatchDate)
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
