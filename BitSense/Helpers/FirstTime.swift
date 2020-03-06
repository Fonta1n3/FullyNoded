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
    
    let aes = AESService()
    let cd = CoreDataService()
    let ud = UserDefaults.standard
    
    func firstTimeHere() {
        print("firstTimeHere")
        
        if ud.object(forKey: "firstTime") == nil {
            
            let password = randomString(length: 32)
            let keychain = KeychainSwift()
            
            if ud.string(forKey: "UnlockPassword") != nil {
                
                keychain.set(ud.string(forKey: "UnlockPassword")!, forKey: "UnlockPassword")
                ud.removeObject(forKey: "UnlockPassword")
                
            }
            
            if keychain.set(password, forKey: "AESPassword") {
                
                print("keychain set AESPassword succesfully")
                ud.set(true, forKey: "firstTime")
                ud.set(true, forKey: "updatedToSwift5")
            
            } else {
                
                print("error setting AESPassword in keychain")
                
            }
            
        }
        
    }
    
}

