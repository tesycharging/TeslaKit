//
//  Codable+JSONString.swift
//  TeslaSwift
//
//  Created by Joao Nunes on 23/09/2017.
//  Copyright © 2017 Joao Nunes. All rights reserved.
//
/*
import Foundation

public extension Encodable {
    
   /* var jsonString: String? {
        let encoder = teslaJSONEncoder
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: String.Encoding.utf8)
    }*/
    
}

public extension String {
    func decodeJSON<T: Decodable>() -> T? {
        guard let data = self.data(using: String.Encoding.utf8) else { return nil }
        return try? teslaJSONDecoder.decode(T.self, from: data)
    }
}*/

