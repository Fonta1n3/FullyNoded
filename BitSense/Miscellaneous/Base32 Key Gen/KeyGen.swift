//
//  KeyGen.swift
//  BitSense
//
//  Created by Peter on 24/10/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import CryptoKit
import Foundation

class KeyGen {
    
    var privKey = ""
    var pubKey = ""
    
    func generate() {
        
        if #available(iOS 13.0, *) {
            
            let privKeyData = Curve25519.Signing.PrivateKey.init()
            let pubKeyData = privKeyData.publicKey
            
            pubKey = base32Encode(pubKeyData.rawRepresentation)
            privKey = base32Encode(privKeyData.rawRepresentation)
            
            print("pubKey = \(pubKey)")
            print("prvKey = \(privKey)")
            
            
        
        }
        
    }
    
}


