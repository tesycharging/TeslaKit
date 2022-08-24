/*//
//  TeslaSwift.swift
//  TeslaSwift
//
//  Created by Joao Nunes on 04/03/16.
//  Copyright © 2016 Joao Nunes. All rights reserved.
//

import Foundation


public enum TeslaError: Error, Equatable {
    case networkError(error: NSError)
    case authenticationRequired
    case authenticationFailed
    case tokenRevoked
    case noTokenToRefresh
    case tokenRefreshFailed
    case invalidOptionsForCommand
    case failedToParseData
    case failedToReloadVehicle
}

let ErrorInfo = "ErrorInfo"


public let teslaJSONEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    encoder.dateEncodingStrategy = .secondsSince1970
    return encoder
}()

public let teslaJSONDecoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    return decoder
}()

*/
