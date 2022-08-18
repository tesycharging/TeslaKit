//
//  Distance.swift
//  Tesy
//
//  Created by David Lüthi on 14.08.22.
//

import Foundation

/// An object representing a distance unit
public struct Distance: CustomStringConvertible {
    public let metric: Double
    
    public let imperial: Double
    
    public static let distFactor: Double = 1.60934
    
    public init(metric: Double) {
        self.metric = metric
        self.imperial = metric / Distance.distFactor
    }
    
    public init(imperial: Double) {
        self.imperial = imperial
        self.metric = imperial * Distance.distFactor
    }
    
    public static func convert(metricToImperial value: Double) -> Double {
        return value / distFactor
    }
    
    public static func convert(imperialToMetric value: Double) -> Double {
        return value * distFactor
    }
    
    ///
    public var localizedMetric: String { return String(format: "%.0f", self.metric) + DistanceUnit.metric.distanceUnit }

    ///
    public var localizedImperial: String { return String(format: "%.0f", self.imperial)  + DistanceUnit.imperial.distanceUnit}

    ///
    public func format(isMetric: Bool) -> String {
        return isMetric ? self.localizedMetric : self.localizedImperial
    }

    ///
    public var description: String {
        return self.localizedMetric + "  " + localizedImperial
    }
}
