//
//  AESService.swift
//  BitSense
//
//  Created by Peter on 04/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation
import CryptoSwift
import KeychainSwift

class AESService {
    
    let keychain = KeychainSwift()
    
    func decryptKey(keyToDecrypt:String) -> String {
        print("decryptKey start")
        
        var stringtoReturn = ""
        
        if let pw = keychain.get("AESPassword") as? String {
            
            do {
                
                let aes = try AES(key: pw, iv: "drowssapdrowssap")
                let decrypted = try aes.decrypt(Array<UInt8>(hex: keyToDecrypt))
                stringtoReturn = String(data: Data(bytes: decrypted), encoding: .utf8)!
                print("decryptKey finish")
                
            } catch {
                
                print("error decrypting")
                
            }
            
        } else {
            
            print("error getting AESPassword from keychain")
            
        }
        
        return stringtoReturn
        
    }
    
    func encryptKey(keyToEncrypt: String) -> String {
        print("encryptKey start")
        
        var stringtoReturn = ""
        
        if let pw = keychain.get("AESPassword") as? String {
            
            do {
                
                let aes = try AES(key: pw, iv: "drowssapdrowssap")
                let encrypted = try aes.encrypt(Array<UInt8>(keyToEncrypt.utf8))
                stringtoReturn = encrypted.toHexString()
                print("encryptKey finished")
                
            } catch {
                
                print("error decrypting")
                
            }
            
        } else {
            
            print("error getting AESPassword from keychain")
            
        }
        
        return stringtoReturn
        
    }
    
}
