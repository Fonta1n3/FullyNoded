//
//  JMUtils.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/21/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

class JMUtils {
    static func createWallet(completion: @escaping ((response: JMWallet?, message: String?)) -> Void) {
        let pass = randomString(length: 20)
        
        let param:[String:Any] = [
            "walletname":"FullyNoded-\(randomString(length: 10)).jmdat",
            "password": pass,
            "wallettype":"sw"
        ]

        JMRPC.sharedInstance.command(method: .walletcreate, param: param) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                completion((nil, errorDesc ?? "Unknown."))
                return
            }
            
            let jmWalletCreated = JMWalletCreated(response)
            
            guard let encryptedToken = Crypto.encrypt(jmWalletCreated.token.utf8),
                  let encryptedWords = Crypto.encrypt(jmWalletCreated.seedphrase.utf8),
                  let encryptedPass = Crypto.encrypt(pass.utf8) else {
                      completion((nil, "Error encrypting jm wallet credentials."))
                      return
                  }
            
            let jmWalletDict:[String:Any] = [
                "id":UUID(),
                "name":jmWalletCreated.walletname,
                "token":encryptedToken,
                "words": encryptedWords,
                "password": encryptedPass
            ]
            
            CoreDataService.saveEntity(dict: jmWalletDict, entityName: .jmWallets) { saved in
                guard saved else {
                    completion((nil, "Error saving jm wallet."))
                    return
                }
                
                completion((response: JMWallet(jmWalletDict), nil))
            }
        }
    }
    
    static func lockWallet(wallet: JMWallet, completion: @escaping ((locked: Bool, message: String?)) -> Void) {
        JMRPC.sharedInstance.command(method: .lockwallet(jmWallet: wallet), param: nil) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                completion((false, errorDesc ?? "Unknown."))
                return
            }
            
            let walletLocked = WalletLocked(response)
            completion((!walletLocked.already_locked, nil))
        }
    }
    
    static func unlockWallet(wallet: JMWallet, completion: @escaping ((unlockedWallet: WalletUnlock?, message: String?)) -> Void) {
        JMRPC.sharedInstance.command(method: .unlockwallet(jmWallet: wallet), param: nil) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                completion((nil, errorDesc ?? "Unknown."))
                return
            }
                        
            let walletUnlock = WalletUnlock(response)
            completion((walletUnlock, nil))
        }
    }
}
