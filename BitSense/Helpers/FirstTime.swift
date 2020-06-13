//
//  FirstTime.swift
//  BitSense
//
//  Created by Peter on 05/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

class FirstTime {
    
    class func firstTimeHere(completion: @escaping ((Bool)) -> Void) {
        if KeyChain.getData("privateKey") == nil {
            /// Sets a new encryption key.
            let pk = Crypto.privateKey()
            if KeyChain.set(pk, forKey: "privateKey") {
                completion(true)
            } else {
                completion(false)
            }
        } else {
            completion(true)
        }
        
    }
    
}

