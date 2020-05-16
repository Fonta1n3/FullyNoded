//
//  HDMusigStruct.swift
//  BitSense
//
//  Created by Peter on 18/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

public struct Wallet: CustomStringConvertible {
    
    let descriptor:Data?
    let id:UUID?
    let index:Int32
    let label:String
    let nodeID:UUID?
    let range:String
    
    init(dictionary: [String: Any]) {
        
        descriptor = dictionary["descriptor"] as? Data
        id = dictionary["id"] as? UUID
        index = dictionary["index"] as? Int32 ?? Int32(0)
        label = dictionary["label"] as? String ?? ""
        nodeID = dictionary["nodeID"] as? UUID
        range = dictionary["range"] as? String ?? ""
        
    }
    
    public var description: String {
        return ""
    }
    
}
