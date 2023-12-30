//
//  Drivenote.swift
//  TeslaKit
//
//  Created by Jaren Hamblin on 29/02/23.
//

import Foundation
import ObjectMapper

///
public struct Drivenote {

    ///
    public var note: String = ""

    ///
    public init() {}

    ///
    public init(note: String) {
        self.note = note
    }
}

extension Drivenote: Mappable {
    public mutating func mapping(map: Map) {
        note <- map["note"]
    }
}
