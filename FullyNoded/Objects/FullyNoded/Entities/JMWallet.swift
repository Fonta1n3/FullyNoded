//
//  JMWallet.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/21/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

public struct JMWallet: CustomStringConvertible {
    let id:UUID
    let name:String
    let password:Data
    //let words:Data
    var token:Data
    //let index:Int
    //let account:Int
    let fnWallet:String
    //let descriptors: Data?
    //let bitcoinCoreWallet: String?
    //let fnWalletId: UUID?
    
    init(_ dictionary: [String: Any]) {
        id = dictionary["id"] as! UUID
        name = dictionary["name"] as! String
        password = dictionary["password"] as! Data
        //words = dictionary["words"] as! Data
        token = dictionary["token"] as! Data
        //account = Int(dictionary["account"] as! Int16)
        //index = Int(dictionary["index"] as! Int16)
        fnWallet = dictionary["fnWallet"] as? String ?? ""
        //descriptors = dictionary["descriptors"] as? Data
        //bitcoinCoreWallet = dictionary["bitcoinCoreWallet"] as? String
        //fnWalletId = dictionary["fnWalletId"] as? UUID
    }
    
    public var description: String {
        return ""
    }
    
}
