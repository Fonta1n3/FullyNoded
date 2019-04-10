//
//  AESService.swift
//  BitSense
//
//  Created by Peter on 04/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation
import AES256CBC
import SwiftKeychainWrapper

class AESService {
    
    static let sharedInstance = AESService()
    
    func decryptKey(keyToDecrypt:String) -> String {
        print("decryptKey")
        
        var stringtoReturn = ""
        
        if let pw = KeychainWrapper.standard.string(forKey: "AESPassword") {
            
            if let check = AES256CBC.decryptString(keyToDecrypt, password: pw) {
                
                stringtoReturn = check
                
            }
            
        }
        
        return stringtoReturn
        
    }
    
    func encryptKey(keyToEncrypt: String) -> String {
        
        var stringtoReturn = ""
        
        if let password = KeychainWrapper.standard.string(forKey: "AESPassword") {
            
            if let check = AES256CBC.encryptString(keyToEncrypt, password: password) {
                
                stringtoReturn = check
                
            }
            
        }
        
        return stringtoReturn
        
    }
    
}
