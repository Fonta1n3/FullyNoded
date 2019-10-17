//
//  HDMusigStruct.swift
//  BitSense
//
//  Created by Peter on 18/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

public struct Wallet: CustomStringConvertible {
    
    let descriptor:String
    let id:String
    let index:String
    let label:String
    let nodeID:String
    let range:String
    
    init(dictionary: [String: Any]) {
        
        self.descriptor = dictionary["descriptor"] as? String ?? ""
        self.id = dictionary["id"] as? String ?? ""
        self.index = dictionary["index"] as? String ?? ""
        self.label = dictionary["label"] as? String ?? ""
        self.nodeID = dictionary["nodeID"] as? String ?? ""
        self.range = dictionary["range"] as? String ?? ""
        
    }
    
    public var description: String {
        return ""
    }
    
}
