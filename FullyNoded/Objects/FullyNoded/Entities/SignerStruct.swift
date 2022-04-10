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
    let words:Data?
    let passphrase:Data?
    let added:Date
    let bip48xpub:Data?
    let bip84xpub:Data?
    let bip48tpub:Data?
    let bip84tpub:Data?
    let xfp:Data?
    let rootTpub:Data?
    let rootXpub:Data?
    
    init(dictionary: [String: Any]) {
        id = dictionary["id"] as! UUID
        label = dictionary["label"] as? String ?? "Signer"
        words = dictionary["words"] as? Data
        passphrase = dictionary["passphrase"] as? Data
        added = dictionary["added"] as? Date ?? Date()
        bip48xpub = dictionary["bip48xpub"] as? Data
        bip84xpub = dictionary["bip84xpub"] as? Data
        bip48tpub = dictionary["bip48tpub"] as? Data
        bip84tpub = dictionary["bip84tpub"] as? Data
        xfp = dictionary["xfp"] as? Data
        rootXpub = dictionary["rootXpub"] as? Data
        rootTpub = dictionary["rootTpub"] as? Data
    }
    
    public var description: String {
        return ""
    }
}
