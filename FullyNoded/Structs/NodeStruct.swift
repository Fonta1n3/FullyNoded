//
//  NodeStruct.swift
//  BitSense
//
//  Created by Peter on 18/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

public struct NodeStruct: CustomStringConvertible {
    
    let id:UUID?
    let label:String
    let isActive:Bool
    let onionAddress:Data?
    let rpcpassword:Data?
    let rpcuser:Data?
    let isLightning:Bool
    let uncleJim:Bool
    
    init(dictionary: [String: Any]) {
        
        id = dictionary["id"] as? UUID
        label = dictionary["label"] as? String ?? ""
        isActive = dictionary["isActive"] as? Bool ?? false
        onionAddress = dictionary["onionAddress"] as? Data
        rpcpassword = dictionary["rpcpassword"] as? Data
        rpcuser = dictionary["rpcuser"] as? Data
        isLightning = dictionary["isLightning"] as? Bool ?? false
        uncleJim = dictionary["uncleJim"] as? Bool ?? false
    }
    
    public var description: String {
        return ""
    }
    
}

