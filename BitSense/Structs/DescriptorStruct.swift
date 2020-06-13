//
//  DescriptorStruct.swift
//  BitSense
//
//  Created by Peter on 22/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

public struct DescriptorStruct: CustomStringConvertible {
    public var description = ""
    
    let label:String
    let id:UUID?
    let descriptor:Data?
    let range:String
    let nodeID:UUID?
    
    init(dictionary: [String:Any]) {
        
        descriptor = dictionary["descriptor"] as? Data
        label = dictionary["label"] as? String ?? ""
        id = dictionary["id"] as? UUID
        range = dictionary["range"] as? String ?? ""
        nodeID = dictionary["nodeID"] as? UUID
        
    }
    
}
