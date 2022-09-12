//
//  StreamMessage.swift
//  TeslaKit
//
//  Created by David Lüthi on 06.03.21
//  Copyright © 2022 David Lüthi. All rights reserved.
//

import Foundation
import ObjectMapper
import CoreLocation

/**
 Stream message with its result
 
 **/
class StreamMessage {
    public var allValues: Map
    
    var messageType: String = ""
    var value: String?
    var tag: String?
    var errorType: String?
    var connectionTimeout: Int?
    var streamResult: StreamResult = StreamResult(values: "")
    
    required init() {
        allValues = Map(mappingType: .fromJSON, JSON: ["":""])
    }
}

extension StreamMessage: DataResponse {
    public func mapping(map: Map) {
        allValues = map
        messageType <- map["msg_type"]
        value <- map["value"]
        tag <- map["tag"]
        errorType <- map["error_type"]
        connectionTimeout <- map["connection_timeout"]
        streamResult = StreamResult(values: value ?? "")
    }
}

open class StreamResult/*: Codable*/ {
    open var timestamp: Double?
    open var speed: CLLocationSpeed? // mph
    open var speedUnit: String?
    open var odometer: Double? // miles
    open var soc: Int?
    open var elevation: Int? // feet
    open var estLat: CLLocationDegrees?
    open var estLng: CLLocationDegrees?
    open var power: Int? // kW
    open var shiftState: String?
    open var range: Double? // miles
    open var estRange: Double? // miles
    open var estHeading: CLLocationDirection?
    open var heading: CLLocationDirection?    
    open var position: CLLocation? {
        if let latitude = estLat,
            let longitude = estLng,
            let heading = heading,
            let timestamp = timestamp {
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            return CLLocation(coordinate: coordinate,
                              altitude: 0.0, horizontalAccuracy: 0.0, verticalAccuracy: 0.0,
                              course: heading,
                              speed: speed ?? 0,
                              timestamp: Date(timeIntervalSince1970: timestamp/1000))
            
        }
        return nil
    }
    
    init(values: String) {
        let separatedValues = values.components(separatedBy: ",")
        guard separatedValues.count > 11 else { return }
        if let timeValue = Double(separatedValues[0]) {
            timestamp = timeValue
        }
        speed = CLLocationSpeed(separatedValues[1])
        odometer = Double(separatedValues[2])
        soc = Int(separatedValues[3])
        elevation = Int(separatedValues[4])
        estHeading = CLLocationDirection(separatedValues[5])
        estLat = CLLocationDegrees(separatedValues[6])
        estLng = CLLocationDegrees(separatedValues[7])
        power = Int(separatedValues[8])
        shiftState = separatedValues[9]
        range = Double(separatedValues[10])
        estRange = Double(separatedValues[11])
        heading = CLLocationDirection(separatedValues[12])
    }
    
   /* enum CodingKeys: String, CodingKey {
        case timestamp
        case speed
        case odometer
        case soc
        case elevation
        case estLat
        case estLng
        case power
        case shiftState
        case range
        case estRange
        case estHeading
        case heading
    }*/
}
