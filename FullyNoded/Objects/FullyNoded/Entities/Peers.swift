//
//  Peers.swift
//  FullyNoded
//
//  Created by Peter on 22/08/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

public struct PeersStruct: CustomStringConvertible {
    
    let id:UUID
    let label:String
    let pubkey:String
    let color:String
    let alias:String
    let uri:String
    
    init(dictionary: [String: Any]) {
        id = dictionary["id"] as! UUID
        label = dictionary["label"] as? String ?? ""
        pubkey = dictionary["pubkey"] as? String ?? ""
        color = dictionary["color"] as? String ?? ""
        alias = dictionary["alias"] as? String ?? ""
        uri = dictionary["uri"] as? String ?? ""
    }
    
    public var description: String {
        return ""
    }
    
}
