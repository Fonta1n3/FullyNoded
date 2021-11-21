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
    let words:Data
    let token:Data
    
    init(_ dictionary: [String: Any]) {
        id = dictionary["id"] as! UUID
        name = dictionary["name"] as! String
        password = dictionary["password"] as! Data
        words = dictionary["words"] as! Data
        token = dictionary["token"] as! Data
    }
    
    public var description: String {
        return ""
    }
    
}
