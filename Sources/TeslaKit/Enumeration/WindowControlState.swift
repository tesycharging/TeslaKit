//
//  WindowControlState.swift
//  Tesy
//
//  Created by David Lüthi on 08.08.22.
//


import Foundation

/// The desired state of the panoramic roof. The approximate percent open values for each state are open = 100%, close = 0%, comfort = 80%, and vent = ~15% Example: open. Possible values:  open , close , comfort , vent , move .
public enum WindowControlState: String, CustomStringConvertible {

    /// close = 0%
    case close

    /// vent = ~15%
    case vent

    public var description: String {
        switch self {
        case .close:
            return "close"
        case .vent:
            return "vent"
        }
    }
}
