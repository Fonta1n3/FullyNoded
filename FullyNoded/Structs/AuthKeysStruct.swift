//
//  AuthKeysStruct.swift
//  BitSense
//
//  Created by Peter on 13/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

public struct AuthKeysStruct: CustomStringConvertible {
    public var description = ""
    let privateKey:Data
    let publicKey:String
    let id:UUID
    init(dictionary: [String:Any]) {
        privateKey = dictionary["privateKey"] as! Data
        publicKey = dictionary["publicKey"] as! String
        id = dictionary["id"] as! UUID
    }
}
