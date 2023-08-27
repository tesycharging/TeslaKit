//
//  TripplanRequest.swift
//  
//
//  Created by David Lüthi on 24.08.23.
//

import Foundation
import ObjectMapper

@available(macOS 13.1, *)
public struct TripplanRequest {

	public var car_trim: String = "74D"
	public var car_type: String = "ModelY"
	public var destination: String = "37.485767, -122.240207"
	public var origin: String = "37.79307,-125.108"
	public var origin_soe: Double = 0.64
	public var vin: String = "5YJSA11111111111"
    

    ///
    public init() {}


    public init(car_trim: String, car_type: String, destination: String, origin: String, origin_soe: Double, vin: String) {
        self.car_trim = car_trim
        self.car_type = car_type
		self.destination = destination
		self.origin = origin
		self.origin_soe = origin_soe
		self.vin = vin
    }
}

extension TripplanRequest: Mappable {
    public mutating func mapping(map: Map) {
        car_trim <- map["car_trim"]
        car_type <- map["car_type"]
		destination <- map["destination"]
		origin <- map["origin"]
        origin_soe <- map["origin_soe"]
		vin <- map["vin"]
    }
}
