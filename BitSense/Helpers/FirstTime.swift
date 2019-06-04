//
//  FirstTime.swift
//  BitSense
//
//  Created by Peter on 05/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation
import SwiftKeychainWrapper

class FirstTime {
    
    func firstTimeHere() {
        print("firstTimeHere")
        
        if UserDefaults.standard.object(forKey: "firstTime") == nil {
            
            UserDefaults.standard.set("bitcoin-cli", forKey: "path")
            
            UserDefaults.standard.set("500", forKey: "miningFee")
            
            let password = randomString(length: 32)
            
            let saveSuccessful:Bool = KeychainWrapper.standard.set(password, forKey: "AESPassword")
            
            if saveSuccessful {
                
                print("Encryption key saved successfully: \(saveSuccessful)")
                UserDefaults.standard.set(true, forKey: "firstTime")
                
            } else {
                
                print("error saving encryption key")
                
            }
            
        }
        
    }
    
}

