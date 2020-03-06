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
    
    /*
     func encryptAndSaveSeed(string: String, completion: @escaping ((Bool)) -> Void) {
         
         if #available(iOS 13.0, *) {
             
             if self.ud.bool(forKey: "privateKeySet") {
                 
                 if let key = self.keychain.getData("privateKey") {
                     
                     let k = SymmetricKey(data: key)
                     
                     if let dataToEncrypt = string.data(using: .utf8) {
                         
                         if let sealedBox = try? ChaChaPoly.seal(dataToEncrypt, using: k) {
                             
                             let encryptedData = sealedBox.combined
                             
                         } else {
                             
                             completion((false))
                             
                         }
                         
                     } else {
                         
                         completion((false))
                         
                     }
                     
                 } else {
                     
                     completion((false))
                     
                 }
                 
             } else {
                 
                 completion((false))
                 
             }
             
         } else {
             
             completion((false))
             
         }
         
     }
     
     func decrypt(data: Data, completion: @escaping ((seed: String, error: Bool)) -> Void) {
         
         if #available(iOS 13.0, *) {
             
             if ud.bool(forKey: "privateKeySet") {
                 
                 if let key = keychain.getData("privateKey") {
                     
                     do {
                         
                         let box = try ChaChaPoly.SealedBox.init(combined: data)
                         let k = SymmetricKey(data: key)
                         let decryptedData = try ChaChaPoly.open(box, using: k)
                         if let seed = String(data: decryptedData, encoding: .utf8) {
                             
                             completion((seed,false))
                             
                         } else {
                             
                             completion(("",true))
                             
                         }
                         
                         
                     } catch {
                         
                         print("failed decrypting")
                         completion(("",true))
                         
                     }
                     
                 } else {
                     
                     completion(("",true))
                     
                 }
                 
             } else {
                 
                 completion(("",true))
                 
             }
             
         } else {
             
             completion(("",true))
             
         }
                 
     }
     
     */
    
}
