//
//  FirstTime.swift
//  BitSense
//
//  Created by Peter on 05/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation
import KeychainSwift

class FirstTime {
    
    func firstTimeHere() {
        print("firstTimeHere")
        
        if UserDefaults.standard.object(forKey: "firstTime") == nil {
            
            UserDefaults.standard.set("bitcoin-cli", forKey: "path")
            
            UserDefaults.standard.set("500", forKey: "miningFee")
            
            let password = randomString(length: 32)
            
            let keychain = KeychainSwift()
            
            if UserDefaults.standard.string(forKey: "UnlockPassword") != nil {
                
                keychain.set(UserDefaults.standard.string(forKey: "UnlockPassword")!, forKey: "UnlockPassword")
                UserDefaults.standard.removeObject(forKey: "UnlockPassword")
                
            }
            
            if keychain.set(password, forKey: "AESPassword") {
                
                print("keychain set AESPassword succesfully")
                UserDefaults.standard.set(true, forKey: "firstTime")
                UserDefaults.standard.set(true, forKey: "updatedToSwift5")
            
            } else {
                
                print("error setting AESPassword in keychain")
                
            }
            
        }
        
    }
    
}

