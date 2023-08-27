//
//  VehicleOption.swift
//  TeslaKit
//
//  Created by Jaren Hamblin on 11/24/17.
//  Copyright © 2018 HamblinSoft. All rights reserved.
//

import Foundation
import os

/// Represents an option of a `Vehicle`. For all options, see TeslaVehicleOptionCodes.plist in Resources.
@available(macOS 13.1, *)
public struct VehicleOption {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: VehicleOption.self))
    
    /// The option code
    public let code: String
    
    /// The option name
    public let name: String
    
    /// The option description
    public let description: String
    
    /// The dicitonary containing the option name and description keyed by the option code
    private static let data: [String: [String: String]] = {
        //let countryCode: String = "US".uppercased()
        guard let url: URL = Bundle.main.url(forResource: "TeslaKit_TeslaKit.bundle/TeslaVehicleOptionCodes", withExtension: "plist"),
            let data: Data = try? Data(contentsOf: url),
            let plist: [String: [String: String]] = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: [String: String]] else {
            VehicleOption.logger.error("\("error, could not read from plist file", privacy: .public)")
            return [:]
        }
        return plist
    }()
    

    /// Default initializer initializing a new `VehicleOption` from a code. The name and description are inferred from the TeslaVehicleOptionCodes.plist in Resources.
    ///
    /// - Parameter code: The vehicle option code
    public init(code: String) {
        self.code = code
        self.name = VehicleOption.data[code]?["name"] ?? ""
        self.description = VehicleOption.data[code]?["description"] ?? ""
    }
}
