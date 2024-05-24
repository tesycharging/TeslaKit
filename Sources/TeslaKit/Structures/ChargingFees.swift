//
//  ChargingFees.swift
//  TeslaKit
//
//  Copyright © 2024 David Lüthi. All rights reserved.
//

import Foundation
import ObjectMapper
import MapKit

public struct ChargingFees {
    public var allValues: Map
    public var currencyCode: String = ""
    public var feeType = "CHARGING"
    public var isPaid: Int = 1
    public var netDue: Double = 0
    public var pricingType = "PAYMENT"
    public var rateBase: Double = 0
    public var rateTier1: Double = 0
    public var rateTier2: Double = 0
    public var rateTier3: Double = 0
    public var rateTier4: Double = 0
    public var sessionFeeId: Int = 0
    public var status = "PAID"
    public var totalBase: Double = 0
    public var totalDue: Double = 0
    public var totalTier1: Double = 0
    public var totalTier2: Double = 0
    public var totalTier3: Double = 0
    public var totalTier4: Double = 0
    public var uom = "kwh"
    public var usageBase: Double = 0
    public var usageTier1: Double = 0
    public var usageTier2: Double = 0
    public var usageTier3: Double = 0
    public var usageTier4: Double = 0
    public init() {
        allValues = Map(mappingType: .fromJSON, JSON: ["":""])
    }
}

extension ChargingFees: DataResponse {
    public mutating func mapping(map: Map) {
        allValues = map
        currencyCode <- map["currencyCode"]
        feeType <- map["feeType"]
        isPaid <- map["isPaid"]
        netDue <- map["netDue"]
        pricingType <- map["pricingType"]
        rateBase <- map["rateBase"]
        rateTier1 <- map["rateTier1"]
        rateTier2 <- map["rateTier2"]
        rateTier3 <- map["rateTier3"]
        rateTier4 <- map["rateTier4"]
        sessionFeeId <- map["sessionFeeId"]
        status <- map["status"]
        totalBase <- map["totalBase"]
        totalDue <- map["totalDue"]
        totalTier1 <- map["totalTier1"]
        totalTier2 <- map["totalTier2"]
        totalTier3 <- map["totalTier3"]
        totalTier4 <- map["totalTier4"]
        uom <- map["uom"]
        usageBase <- map["usageBase"]
        usageTier1 <- map["usageTier1"]
        usageTier2 <- map["usageTier2"]
        usageTier3 <- map["usageTier3"]
        usageTier4 <- map["usageTier4"]
    }
}

extension ChargingFees: Hashable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.sessionFeeId == rhs.sessionFeeId
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(sessionFeeId)
    }
}
