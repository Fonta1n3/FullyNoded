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
    let type:String
    var name:String
    let maxIndex:Int64
    let index:Int64
    var watching:[String]?
    let account:Int16
    let blockheight:Int
    let isJm: Bool
    var token: Data?
    var password: Data?
    var jmWalletName: String
    var dict: [String:Any]
    
    init(dictionary: [String: Any]) {
        dict = dictionary
        id = dictionary["id"] as! UUID
        label = dictionary["label"] as? String ?? "Add label"
        changeDescriptor = dictionary["changeDescriptor"] as? String ?? ""
        receiveDescriptor = dictionary["receiveDescriptor"] as? String ?? ""
        type = dictionary["type"] as! String
        name = dictionary["name"] as? String ?? ""
        maxIndex = dictionary["maxIndex"] as? Int64 ?? 0
        index = dictionary["index"] as? Int64 ?? 0
        watching = dictionary["watching"] as? [String]
        account = dictionary["account"] as? Int16 ?? 0
        blockheight = Int(exactly: dictionary["blockheight"] as? Int64 ?? 0)!
        isJm = dictionary["isJm"] as? Bool ?? false
        token = dictionary["token"] as? Data
        password = dictionary["password"] as? Data
        jmWalletName = dictionary["jmWalletName"] as? String ?? ""
    }
    
    public var description: String {
        return ""
    }
}
