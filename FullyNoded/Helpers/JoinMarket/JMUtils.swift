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
            let signer = jmWalletCreated.seedphrase
            
            guard let encryptedToken = Crypto.encrypt(jmWalletCreated.token.utf8),
                  let encryptedWords = Crypto.encrypt(signer.utf8),
                  let encryptedPass = Crypto.encrypt(pass.utf8) else {
                      completion((nil, "Error encrypting jm wallet credentials."))
                      return
                  }
            
            let dict = ["id":UUID(), "words":encryptedWords, "added": Date(), "label": "Join Market"] as [String:Any]
            CoreDataService.saveEntity(dict: dict, entityName: .signers) { success in
                guard success else {
                    completion((nil, "Unable to save the signer."))
                    return
                }
                
                var cointType = "0"
                let chain = UserDefaults.standard.object(forKey: "chain") as? String ?? "main"
                if chain != "main" {
                    cointType = "1"
                }
                
                let blockheight = UserDefaults.standard.object(forKey: "blockheight") as? Int ?? 0
                
                guard let mk = Keys.masterKey(words: signer, coinType: cointType, passphrase: ""),
                      let xfp = Keys.fingerprint(masterKey: mk) else {
                    completion((nil, "Error deriving master key."))
                    return
                }
                
                JoinMarket.descriptors(mk, xfp) { descriptors in
                    guard var descriptors = descriptors else {
                        completion((nil, "Error creating your jm descriptors."))
                        return
                    }
                    
                    let accountMap:[String:Any] = [
                        "descriptor":descriptors.removeFirst(),
                        "blockheight": blockheight,
                        "watching":descriptors,
                        "label":"Join Market"
                    ]
                                    
                    ImportWallet.accountMap(accountMap) { (success, errorDescription) in
                        guard success else {
                            completion((nil, errorDescription ?? "Unknown."))
                            return
                        }
                        
                        activeWallet(completion: { activeWallet
                            in
                            guard let activeWallet = activeWallet else {
                                return
                            }
                            
                            let jmWalletDict:[String:Any] = [
                                "id":UUID(),
                                "name":jmWalletCreated.walletname,
                                "token":encryptedToken,
                                "words": encryptedWords,
                                "password": encryptedPass,
                                "account": Int16(0),
                                "index": Int16(0),
                                "fnWallet": activeWallet.name
                            ]
                            
                            CoreDataService.saveEntity(dict: jmWalletDict, entityName: .jmWallets) { saved in
                                guard saved else {
                                    completion((nil, "Error saving jm wallet."))
                                    return
                                }
                                
                                completion((response: JMWallet(jmWalletDict), nil))
                            }
                        })
                    }
                }
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
            
            guard let updatedToken = Crypto.encrypt(walletUnlock.token.utf8) else {
                completion((nil, "Unable to encrypt new token."))
                return
            }
            
            CoreDataService.update(id: wallet.id, keyToUpdate: "token", newValue: updatedToken, entity: .jmWallets) { updated in
                guard updated else {
                    completion((nil, "Unable to save new token."))
                    return
                }
                
                completion((walletUnlock, nil))
            }
        }
    }
    
    static func syncIndexes(wallet: JMWallet, completion: @escaping ((String?)) -> Void) {
        JMRPC.sharedInstance.command(method: .walletdisplay(jmWallet: wallet), param: nil) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                completion((errorDesc ?? "Unknown."))
                return
            }
            var lastUsedIndex = 0
            var nextAccount = 0
            let walletDetail = WalletDetail(response)
            
            for (i, account) in walletDetail.accounts.enumerated() {
                if account.accountNumber > 0 {
                    // this is incrementing the account number when it should just be the index
                    for branch in account.branches {
                        for entry in branch.entries {
                            if entry.amount > 0 {
                                let arr = entry.hd_path.split(separator: "/")
                                lastUsedIndex = Int("\(arr[arr.count - 1])")!
                                
                                if lastUsedIndex == 4 {
                                    nextAccount += 1
                                }
                            }
                        }
                    }
                }
                
                if i + 1 == walletDetail.accounts.count {
                    CoreDataService.update(id: wallet.id, keyToUpdate: "index", newValue: Int16(lastUsedIndex + 1), entity: .jmWallets) { updated in
                        guard updated else {
                            completion(("Error updating index."))
                            return
                        }
                        
                        CoreDataService.update(id: wallet.id, keyToUpdate: "account", newValue: Int16(nextAccount), entity: .jmWallets) { updated in
                            guard updated else {
                                completion(("Error updating account."))
                                return
                            }
                            
                            completion((nil))
                        }
                    }
                }
            }
        }
    }
    
    static func getAddress(wallet: JMWallet, completion: @escaping ((address: String?, message: String?)) -> Void) {
        JMUtils.syncIndexes(wallet: wallet) { message in
            JMRPC.sharedInstance.command(method: .getaddress(jmWallet: wallet), param: nil) { (response, errorDesc) in
                guard let response = response as? [String:Any],
                let address = response["address"] as? String else {
                    completion((nil, errorDesc ?? "unknown"))
                    return
                }
                
                completion((address, message))
            }
        }
    }
    
    static func coinjoin(wallet: JMWallet,
                         amount_sats: Int,
                         mixdepth: Int,
                         counterparties: Int,
                         address: String,
                         completion: @escaping ((response: [String:Any]?, message: String?)) -> Void) {
        
        let param:[String:Any] = [
            "amount_sats":amount_sats,
            "mixdepth":mixdepth,
            "counterparties":counterparties,
            "destination": address
        ]
        
        JMRPC.sharedInstance.command(method: .coinjoin(jmWallet: wallet), param: param) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                completion((nil, errorDesc ?? "unknown"))
                return
            }
            
            guard let errorDesc = errorDesc else {
                completion((response, errorDesc))
                return
            }
            
            completion((response, errorDesc))
        }
    }
    
    static func makerStart(wallet: JMWallet,
                           txfee: Int,
                           cjfee_a: Int,
                           cjfee_r: Int,
                           ordertype: String,
                           minsize: Int,
                           completion: @escaping ((response: [String:Any]?, message: String?)) -> Void) {
        
        let param:[String:Any] = [
            "txfee":txfee,
            "cjfee_a":cjfee_a,
            "cjfee_r":cjfee_r,
            "ordertype": ordertype,
            "minsize": minsize
        ]
        
        JMRPC.sharedInstance.command(method: .coinjoin(jmWallet: wallet), param: param) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                      completion((nil, errorDesc ?? "unknown"))
                      return
                  }
            
            completion((response, errorDesc))
        }
    }
    
    static func configGet(wallet: JMWallet,
                          section: String,
                          field: String,
                          completion: @escaping ((response: String?, message: String?)) -> Void) {
        
        let param:[String:Any] = [
            "section":section,
            "field":field
        ]
        
        JMRPC.sharedInstance.command(method: .configGet(jmWallet: wallet), param: param) { (response, errorDesc) in
            guard let response = response as? [String:Any],
                  let value = response["configvalue"] as? String else {
                      completion((nil, errorDesc ?? "unknown"))
                      return
                  }
            
            completion((value, errorDesc))
        }
    }
    
    static func configSet(wallet: JMWallet,
                          section: String,
                          field: String,
                          value: String,
                          completion: @escaping ((response: [String:Any]?, message: String?)) -> Void) {
        
        let param:[String:Any] = [
            "section":section,
            "field":field,
            "value":value
        ]
        
        JMRPC.sharedInstance.command(method: .configSet(jmWallet: wallet), param: param) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                      completion((nil, errorDesc ?? "unknown"))
                      return
                  }
            
            completion((response, errorDesc))
        }
    }
    
    static func session(completion: @escaping ((response: JMSession?, message: String?)) -> Void) {
        JMRPC.sharedInstance.command(method: .session, param: nil) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                completion((nil, errorDesc))
                return }
            
            completion((JMSession(response), nil))
        }
    }
}
