//
//  Alerts.swift
//  TeslaKit
//
//  Copyright © 2022 David Lüthi. All rights reserved.
//

import Foundation
import ObjectMapper
import MapKit

public struct Alerts {
    public var recent_alerts: [Recent_Alert] = []
    public init() {}
    public init(recent_alerts: [Recent_Alert]) {
        self.recent_alerts = recent_alerts
    }
}

extension Alerts: Mappable {
    public mutating func mapping(map: Map) {
        recent_alerts <- map["recent_alerts"]
    }
}

public struct Recent_Alert {
    public var allValues: Map
    public var name: String = ""
    public var time: String = ""
    public var audience: [String] = []
    public var user_text: String = ""
    public init() {
        allValues = Map(mappingType: .fromJSON, JSON: ["":""])
    }
}

extension Recent_Alert: DataResponse {
    public mutating func mapping(map: Map) {
        allValues = map
        name <- map["name"]
        time <- map["time"]
        audience <- map["audience"]
        user_text <- map["user_text"]
    }
}

extension Recent_Alert: Hashable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.name == rhs.name
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}
