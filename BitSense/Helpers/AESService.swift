//
//  AESService.swift
//  BitSense
//
//  Created by Peter on 04/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation
import CryptoSwift

class AESService {
    
    func decryptOldKey(keyToDecrypt:String) -> String {
        print("decryptKey start")
        
        var stringtoReturn = ""
        
        if let pw = KeyChain.getData("AESPassword") {
            
            do {
                
                if let passwordString = String(bytes: pw, encoding: .utf8) {
                    let aes = try AES(key: passwordString, iv: "drowssapdrowssap")
                    let decrypted = try aes.decrypt(Array<UInt8>(hex: keyToDecrypt))
                    stringtoReturn = String(data: Data(decrypted), encoding: .utf8)!
                    print("decryptKey finish")
                    
                } else {
                    print("error decrypting")
                    
                }
                
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
        
//        if let pw = KeyChain.getData("AESPassword") {
//
//            do {
//
//                if let passwordString = String(bytes: pw, encoding: .utf8) {
//                    let aes = try AES(key: passwordString, iv: "drowssapdrowssap")
//                    let encrypted = try aes.encrypt(Array<UInt8>(keyToEncrypt.utf8))
//                    stringtoReturn = encrypted.toHexString()
//                    print("encryptKey finished")
//
//                } else {
//                    print("error decrypting")
//
//                }
//
//            } catch {
//                print("error decrypting")
//
//            }
//
//        } else {
//            print("error getting AESPassword from keychain")
//
//        }
        
        return stringtoReturn
        
    }
    
    
    
}
