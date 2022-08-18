//
//  Speed.swift
//  Tesy
//
//  Created by David Lüthi on 14.08.22.
//

import Foundation

/// An object representing a speed unit
public struct Speed: CustomStringConvertible {
    public let metric: Double
    
    public let imperial: Double
    
    public init(metric: Int) {
        self.metric = Double(metric)
        self.imperial = self.metric / Distance.distFactor
    }
    
    public init(imperial: Int) {
        self.imperial = Double(imperial)
        self.metric = self.imperial * Distance.distFactor
    }
    
    public static func convert(metricToImperial value: Double) -> Double {
        return value / Distance.distFactor
    }
    
    public static func convert(imperialToMetric value: Double) -> Double {
        return value * Distance.distFactor
    }
    
    ///
    public var localizedMetric: String { return String(format: "%.0f", self.metric) + DistanceUnit.metric.speedUnit}

    ///
    public var localizedImperial: String { return String(format: "%.0f", self.imperial) + DistanceUnit.imperial.speedUnit}

    ///
    public func format(isMetric: Bool) -> String {
        return isMetric ? self.localizedMetric : self.localizedImperial
    }

    ///
    public var description: String {
        return self.localizedMetric + "  " + localizedImperial
    }
}
