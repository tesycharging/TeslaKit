//
//  ErrorMessage.swift
//  TeslaSwift
//
//  Created by Joao Nunes on 28/02/2017.
//  Copyright © 2017 Joao Nunes. All rights reserved.
//

import Foundation

open class ErrorMessage: Codable {
    
    open var error: String?
    open var description: String?
    
    enum CodingKeys: String, CodingKey {
        case error         = "error"
        case description = "error_description"
    }
}
