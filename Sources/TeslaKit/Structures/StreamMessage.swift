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

open class StreamResult {
    open var speed: Int?
    open var shiftState: ShiftState = ShiftState.park
    open var latitude: Double?
    open var longitude: Double?
    open var headingValue: Double?
    open var timestamp: Double?
    open var odometer: Double? // miles
	open var elevation: Int? // feet
	open var power: Int?
    open var soc: Int?    
    open var range: Double? // miles
    open var estRange: Double? // miles
    
    init(values: String) {
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
