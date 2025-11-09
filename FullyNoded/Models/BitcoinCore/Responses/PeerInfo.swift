//
//  PeerInfo.swift
//  BitSense
//
//  Created by Peter on 27/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

public struct PeerInfo: CustomStringConvertible {
    
    let incomingCount: Int
    let outgoingCount: Int
    let rawData: NSArray
    
    init(dictionary: [String: Any]) {
        self.incomingCount = dictionary["incomingCount"] as? Int ?? 0
        self.outgoingCount = dictionary["outgoingCount"] as? Int ?? 0
        self.rawData = dictionary["rawData"] as? NSArray ?? []
    }
    
    public var description: String {
        return "Peer Info"
    }
}
