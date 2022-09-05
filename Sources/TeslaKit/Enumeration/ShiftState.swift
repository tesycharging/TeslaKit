//
//  ShiftState.swift
//  TeslaKit
//
//  Update by David Lüthi on 10.06.2021
//  based on code from Jaren Hamblin on 11/20/17.
//  Copyright © 2022 David Lüthi. All rights reserved.
//

import Foundation

///
public enum ShiftState: String, CustomStringConvertible {

    ///
    case drive = "D"

    ///
    case park = "P"

    ///
    case neutral = "N"

    ///
    case reverse = "R"

    ///
    public var description: String {
        switch self {
        case .drive: return "Drive"
        case .park: return "Park"
        case .neutral: return "Neutral"
        case .reverse: return "Reverse"
        }
    }
    
    ///
    public var systemnameImage: String {
        switch self {
        case .drive: return "d.circle"
        case .park: return "p.circle"
        case .neutral: return "n.circle"
        case .reverse: return "r.circle"
        }
    }
    
}
