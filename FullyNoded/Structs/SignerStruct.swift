//
//  SignerStruct.swift
//  BitSense
//
//  Created by Peter on 04/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

public struct SignerStruct: CustomStringConvertible {
    
    let id:UUID
    let label:String
    let words:Data
    let passphrase:Data?
    let added:Date
    
    init(dictionary: [String: Any]) {
        id = dictionary["id"] as! UUID
        label = dictionary["label"] as? String ?? "Signer"
        words = dictionary["words"] as! Data
        passphrase = dictionary["passphrase"] as? Data
        added = dictionary["added"] as? Date ?? Date()
    }
    
    public var description: String {
        return ""
    }
}
