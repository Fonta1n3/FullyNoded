//
//  MiningInfo.swift
//  BitSense
//
//  Created by Peter on 27/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

public struct MiningInfo: CustomStringConvertible {
    
    let hashrate: String
    let rawData: [String: Any]
    
    init(dictionary: [String: Any]) {
        self.hashrate = dictionary["networkhashps"] as? String ?? ""
        self.rawData = dictionary
    }
    
    public var description: String {
        return "Mining Info"
    }
}
