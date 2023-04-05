//
//  PeerInfo.swift
//  BitSense
//
//  Created by Peter on 27/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

public struct PeerInfo: CustomStringConvertible {
    
    let incomingCount:Int
    let outgoingCount:Int
    
    init(dictionary: [String: Any]) {
        self.incomingCount = dictionary["incomingCount"] as? Int ?? 0
        self.outgoingCount = dictionary["outgoingCount"] as? Int ?? 0
    }
    
    public var description: String {
        return ""
    }
}
