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
    let id:String
    let descriptor:String
    let range:String
    let nodeID:String
    
    init(dictionary: [String:Any]) {
        
        self.descriptor = dictionary["descriptor"] as? String ?? ""
        self.label = dictionary["label"] as? String ?? ""
        self.id = dictionary["id"] as? String ?? ""
        self.range = dictionary["range"] as? String ?? ""
        self.nodeID = dictionary["nodeID"] as? String ?? "ooops"
        
    }
    
}
