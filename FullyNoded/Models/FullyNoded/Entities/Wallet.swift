//
//  Wallet.swift
//  BitSense
//
//  Created by Peter on 28/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

public struct Wallet: CustomStringConvertible {
    
    let id:UUID
    let label:String
    var changeDescriptor:String
    var receiveDescriptor:String
    var name:String
    let blockheight:Int
    var dict: [String:Any]
    
    init(dictionary: [String: Any]) {
        dict = dictionary
        id = dictionary["id"] as! UUID
        label = dictionary["label"] as? String ?? "Add label"
        changeDescriptor = dictionary["changeDescriptor"] as? String ?? ""
        receiveDescriptor = dictionary["receiveDescriptor"] as? String ?? ""
        name = dictionary["name"] as? String ?? ""
        blockheight = Int(exactly: dictionary["blockheight"] as? Int64 ?? 0)!
    }
    
    public var description: String {
        return ""
    }
}
