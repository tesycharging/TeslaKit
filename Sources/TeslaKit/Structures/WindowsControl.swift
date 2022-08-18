//
//  WindowsControl.swift
//  Tesy
//
//  Created by David Lüthi on 08.08.22.
//
import Foundation
import ObjectMapper

public struct WindowsControl {
    
    public var command: WindowControlState = .close
  
    public var lat: Double = 0
    
    public var lon: Double = 0
    
    public init() {}
    
    public init(command: WindowControlState, lat: Double, lon: Double ) {
        self.command = command
        self.lat = lat
        self.lon = lon
    }
}

extension WindowsControl: Mappable {
    public init?(map: Map) {
        print("INIT WINDOWSCONTROL")
    }
    
    public mutating func mapping(map: Map) {
        command <- map["command"]
        lat <- map["lat"]
        lon <- map["lon"]
    }
}
