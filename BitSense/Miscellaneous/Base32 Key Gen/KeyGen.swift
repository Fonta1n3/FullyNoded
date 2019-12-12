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
            
            let privKeyRaw = Curve25519.Signing.PrivateKey.init()
            let pubKeyRaw = privKeyRaw.publicKey
            
            let privKeyData = privKeyRaw.rawRepresentation
            let pubkeyData = pubKeyRaw.rawRepresentation
            
            let privkeyBase64 = privKeyData.base64EncodedString()
            let pubkeyBase64 = pubkeyData.base64EncodedString()
            
            let privkeyBase32 = privkeyBase64.base32EncodedString
            let pubkeyBase32 = pubkeyBase64.base32EncodedString
            
            privKey = privkeyBase32.replacingOccurrences(of: "=", with: "")
            pubKey = pubkeyBase32.replacingOccurrences(of: "=", with: "")
        
        }
        
    }
    
}


