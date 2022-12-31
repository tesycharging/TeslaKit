//
//  ShareParam.swift
//  
//
//  Created by David Lüthi on 27.12.22.
//

import Foundation
import ObjectMapper

public struct ShareParam: TKMappable {
    
    public var type: String = "share_ext_content_raw"
    
    public var locale: String = "en-US"
    
    public var timestamp_ms: TimeInterval = 0
    
    public var value: [String: Any] = ["": ""]
    
    public init(locale: String = Locale.preferredLanguages.first ?? "en-US", text: String = "android.intent.extra.TEXT", value: String) {
        self.locale = locale
        self.timestamp_ms = TimeInterval(Int(Date().timeIntervalSince1970))
        self.value = [text: value]
    }
    
    public init(latitude: Double, longitude: Double) {
        self.locale = Locale.preferredLanguages.first ?? "en-US"
        self.timestamp_ms = TimeInterval(Int(Date().timeIntervalSince1970))
        self.value = ["android.intent.extra.TEXT": "https://www.google.com/maps/place/\(latitude),\(longitude)"]
    }
    
    ///
    public mutating func mapping(map: Map) {
        type <- (map["type"])
        locale <- map["locale"]
        timestamp_ms <- map["timestamp_ms"]
        value <- map["value"]
    }
}
