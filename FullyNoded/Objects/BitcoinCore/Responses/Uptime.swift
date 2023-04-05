//
//  Uptime.swift
//  BitSense
//
//  Created by Peter on 27/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

public struct Uptime: CustomStringConvertible {
    
    let uptime:Int
    
    init(dictionary: [String: Any]) {
        self.uptime = dictionary["uptime"] as? Int ?? 0
    }
    
    public var description: String {
        return ""
    }
}
