//
//  ChargePortLatchState.swift
//  TeslaKit
//
//  Update by David Lüthi on 10.06.2021
//  based on code from Jaren Hamblin on 2/5/18.
//  Copyright © 2022 David Lüthi. All rights reserved.
//

import Foundation

/// The state of the charge port latch. The charge port latch locks the charging connector to the vehicle.
public enum ChargePortLatchState: String, CustomStringConvertible {

    ///
    case unknown = ""

    ///
    case disengaged = "Disengaged"

    ///
    case engaged = "Engaged"

    ///
    public var description: String {
        return self.rawValue
    }
}
