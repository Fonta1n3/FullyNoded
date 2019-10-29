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
            
            pubKey = (base32Encode(pubKeyData.rawRepresentation)).replacingOccurrences(of: "====", with: "")
            privKey = (base32Encode(privKeyData.rawRepresentation)).replacingOccurrences(of: "====", with: "")
            
            let utf8PubKey = pubKey.base32DecodedString(String.Encoding.utf8)
            let utf8PrivKey = privKey.base32DecodedString(String.Encoding.utf8)
            
            print("utf8Pubkey = \(String(describing: utf8PubKey))")
            print("utf8PrivKey = \(String(describing: utf8PrivKey))")
            
            print("pubKey = \(pubKey)")
            print("prvKey = \(privKey)")
            
//            need to format the keys like so:
            
            //already do this
            
//            def key_str(key):
//            # bytes to base 32
//            key_bytes = bytes(key)
//            key_b32 = base64.b32encode(key_bytes)
            
            // so just do this
            
//            # strip trailing ====
//            assert key_b32[-4:] == b'===='
//            key_b32 = key_b32[:-4]
//            # change from b'ASDF' to ASDF
//            s = key_b32.decode('utf-8')
//            return s
        
        }
        
    }
    
}


