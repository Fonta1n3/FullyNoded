//
//  FirstTime.swift
//  BitSense
//
//  Created by Peter on 05/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

enum FirstTime {
    
    static func firstTimeHere() -> Bool {
        if KeyChain.getData("privateKey") == nil {
            /// Sets a new encryption key.
            return KeyChain.set(Crypto.privateKey(), forKey: "privateKey")
        } else {
            return true
        }
    }
    
}

