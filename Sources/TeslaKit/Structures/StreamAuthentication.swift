//
//  StreamAuthentication.swift
//  TeslaKit
//
//  Created by David Lüthi on 06.03.21
//  Copyright © 2022 David Lüthi. All rights reserved.
//

import Foundation

/**
 Message to authenticate for the stream
 
 **/

class StreamAuthentication: Encodable {
    var messageType: String
    var token: String
    var value = "speed,odometer,soc,elevation,est_heading,est_lat,est_lng,power,shift_state,range,est_range,heading"
    var tag: String
    
    init?(vehicleId: String, accessToken: String) {
        self.messageType = "data:subscribe_oauth"
        self.token = accessToken ?? ""
        self.tag = vehicleId
    }
    
    enum CodingKeys: String, CodingKey {
        case messageType = "msg_type"
        case token
        case value
        case tag
    }
}



