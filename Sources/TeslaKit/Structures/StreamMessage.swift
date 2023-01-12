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
public class StreamMessage {
    public var allValues: Map
    
    public var messageType: String = ""
    public var value: String?
    public var tag: String?
    public var errorType: String?
    public var connectionTimeout: Int?
    public var streamResult: StreamResult = StreamResult(values: "")
    
    required public init() {
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

public class StreamResult {
    public var speed: Int?
    public var shiftState: ShiftState = ShiftState.park
    public var latitude: Double?
    public var longitude: Double?
    public var headingValue: Double?
    public var timestamp: Double?
    public var odometer: Double? // miles
    public var elevation: Int? // feet
    public var power: Int?
    public var soc: Int?
    public var range: Double? // miles
    public var estRange: Double? // miles
    public var coordinate: CLLocationCoordinate2D?
    
    public init(values: String) {
        let separatedValues = values.components(separatedBy: ",")
        guard separatedValues.count > 11 else { return }
        if let timeValue = Double(separatedValues[0]) {
            timestamp = timeValue
        }
		
		speed = Int(separatedValues[1])
		odometer = Double(separatedValues[2])
        soc = Int(separatedValues[3])
		elevation = Int(separatedValues[4])
		headingValue = Double(separatedValues[5])
		latitude = Double(separatedValues[6])
        longitude = Double(separatedValues[7])
		power = Int(separatedValues[8])
        switch (separatedValues[9]) {
		case "D":
			shiftState = ShiftState.drive
		case "R":
			shiftState = ShiftState.reverse
		case "N":
			shiftState = ShiftState.neutral
		default:
			shiftState = ShiftState.park
		}
		range = Double(separatedValues[10])
        estRange = Double(separatedValues[11])
        if let lat = latitude, let long = longitude {
            coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
        } else {
            coordinate = nil
        }
    }
}

extension StreamResult {
    public func localizedOdometer(distanceUnit: DistanceUnit) -> String {
        if distanceUnit == .metric {
            return Distance(imperial: odometer ?? 0).localizedMetric
        } else {
            return Distance(imperial: odometer ?? 0).localizedImperial
        }
    }
    
    public func localizedSpeed(distanceUnit: DistanceUnit) -> String {
        if distanceUnit == .imperial {
            return Speed(imperial: self.speed ?? 0).localizedImperial
        } else {
            return Speed(imperial: self.speed ?? 0).localizedMetric
        }
    }
    
    public var heading: Heading {
        switch Double(self.headingValue ?? 0) {
        case 0..<22.5: return .north
        case 22.5..<67.5: return .northEast
        case 67.5..<112.5: return .east
        case 112.5..<157.5: return .southEast
        case 157.5..<202.5: return .south
        case 202.5..<247.5: return .southWest
        case 247.5..<292.5: return .west
        case 292.5..<337.5: return .northWest
        case 337.5..<360: return .north
        default: return .north
        }
    }
}
