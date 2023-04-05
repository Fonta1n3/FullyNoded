//
//  JMUtils.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/21/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

class JMUtils {
    static func getDescriptors(wallet: Wallet, completion: @escaping ((descriptors: [String]?,  message: String?)) -> Void) {
        JMRPC.sharedInstance.command(method: .getSeed(jmWallet: wallet), param: nil) { (response, errorDesc) in
            guard let dict = response as? [String:Any],
                  let words = dict["seedphrase"] as? String else {
                completion((nil, errorDesc))
                return
            }
            
            let chain = UserDefaults.standard.string(forKey: "chain")
            var coinType = "0"
            if chain != "main" {
                coinType = "1"
            }
            
            guard let mk = Keys.masterKey(words: words, coinType: coinType, passphrase: ""),
                  let xfp = Keys.fingerprint(masterKey: mk) else {
                completion((nil, "error deriving mk/xfp."))
                return
            }
            
            JoinMarket.descriptors(mk, xfp, completion: { descriptors in
                guard let descriptors = descriptors else { completion((nil, "error deriving descriptors")); return }
                
                completion((descriptors, nil))
            })
        }
    }
    
    static func createWallet(completion: @escaping ((response: Wallet?,
                                                     words: String?,
                                                     passphrase: String?,
                                                     message: String?)) -> Void) {
        
        guard let passwordWords = Keys.seed() else { return }
        let arr = passwordWords.split(separator: " ")
        var password = ""
        
        for (i, word) in arr.enumerated() {
            if i <= 6 {
                password += word + " "
            }
        }
        
        let jmWalletName = "FullyNoded-\(randomString(length: 6).uppercased()).jmdat"
        
        let param:[String:Any] = [
            "walletname": jmWalletName,
            "password": password,
            "wallettype":"sw-fb"
        ]
        
        JMRPC.sharedInstance.command(method: .walletcreate, param: param) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                completion((nil, nil, nil, errorDesc ?? "Unknown."))
                return
            }
            
            let jmWalletCreated = JMWalletCreated(response)
            let signer = jmWalletCreated.seedphrase
            
            guard let encryptedToken = Crypto.encrypt(jmWalletCreated.token.utf8),
                  let encryptedWords = Crypto.encrypt(signer.utf8),
                  let encryptedPass = Crypto.encrypt(password.utf8) else {
                completion((nil, nil, nil, "Error encrypting jm wallet credentials."))
                return
            }
            
            let dict:[String:Any] = [
                "id": UUID(),
                "words": encryptedWords,
                "added": Date(),
                "label": "Join Market"
            ]
            
            CoreDataService.saveEntity(dict: dict, entityName: .signers) { success in
                guard success else {
                    completion((nil, nil, nil, "Unable to save the signer."))
                    return
                }
                
                let (mk, xfp, block) = getMkXfpBlock(signer: signer)
                guard let mk = mk, let xfp = xfp, let block = block else { return }
                
                let fnWalletId = UUID()
                
                JoinMarket.descriptors(mk, xfp) { descriptors in
                    guard let descriptors = descriptors else {
                        completion((nil, nil, nil, "Error creating your jm descriptors."))
                        return
                    }
                    
                    var fnWallet:[String:Any] = [
                        "receiveDescriptor":descriptors[0],
                        "changeDescriptor":descriptors[1],
                        "blockheight": block,
                        "watching":Array(descriptors[2...descriptors.count - 1]),
                        "label":"Join Market",
                        "index": Int64(0),
                        "maxIndex": 100,
                        "type": "Single-Sig",
                        "isJm": true,
                        "id": fnWalletId,
                        "token":encryptedToken,
                        "password": encryptedPass,
                        "jmWalletName": jmWalletName,
                        "name": ""
                    ]
                    
                    JMUtils.configGet(wallet: Wallet(dictionary: fnWallet), section: "BLOCKCHAIN", field: "rpc_wallet_file") { (jm_rpc_wallet, message) in
                        guard let jm_rpc_wallet = jm_rpc_wallet else {
                            completion((nil, nil, nil, message ?? "error fetching Bitcoin Core rpc wallet name in jm config."))
                            return
                        }
                        
                        fnWallet["name"] = jm_rpc_wallet
                        
                        CoreDataService.saveEntity(dict: fnWallet, entityName: .wallets) { fnWalletSaved in
                            guard fnWalletSaved else {
                                completion((nil, nil, nil, "Error saving fn wallet."))
                                return
                            }
                            
                            completion((Wallet(dictionary: fnWallet), signer, password, nil))
                        }
                    }
                }
            }
        }
    }
    
    static func getMkXfpBlock(signer: String) -> (mk: String?, xfp: String?, block: Int?) {
        var cointType = "0"
        let chain = UserDefaults.standard.object(forKey: "chain") as? String ?? "main"
        if chain != "main" {
            cointType = "1"
        }
        let blockheight = UserDefaults.standard.object(forKey: "blockheight") as? Int ?? 0
        
        guard let mk = Keys.masterKey(words: signer, coinType: cointType, passphrase: ""),
              let xfp = Keys.fingerprint(masterKey: mk) else {
                  return (nil, nil, nil)
              }
        
        return (mk, xfp, blockheight)
    }
    
    static func lockWallet(wallet: Wallet, completion: @escaping ((locked: Bool, message: String?)) -> Void) {
        JMRPC.sharedInstance.command(method: .lockwallet(jmWallet: wallet), param: nil) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                completion((false, errorDesc ?? "Unknown."))
                return
            }
            
            let walletLocked = WalletLocked(response)
            completion((!walletLocked.already_locked, nil))
        }
    }
    
    static func unlockWallet(wallet: Wallet, completion: @escaping ((unlockedWallet: WalletUnlock?, message: String?)) -> Void) {
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
            
            CoreDataService.update(id: wallet.id, keyToUpdate: "token", newValue: updatedToken, entity: .wallets) { _ in }
            completion((walletUnlock, nil))            
        }
    }

    
    static func display(wallet: Wallet, completion: @escaping ((detail: WalletDetail?, message: String?)) -> Void) {
        JMRPC.sharedInstance.command(method: .walletdisplay(jmWallet: wallet), param: nil) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                completion((nil, errorDesc ?? "Unknown."))
                return
            }
            
            completion((WalletDetail(response), nil))
        }
    }
    
    static func getAddress(wallet: Wallet, mixdepth: Int, completion: @escaping ((address: String?, message: String?)) -> Void) {
        JMUtils.unlockWallet(wallet: wallet) { (unlockedWallet, message) in
            var updatedWallet = wallet
            
            guard let unlockedWallet = unlockedWallet else {
                
                if let message = message {
                    if message.contains("Wallet cannot be created/opened, it is locked.") {
                        completion((nil, "Delete the hidden .lock file on your JM wallet located at /.joinmarket/wallets/.\(wallet.name).lock and try again.\n\nDO NOT DELETE THE ACTUAL WALLET FILE!"))
                    } else {
                        completion((nil, message))
                    }
                } else {
                    completion((nil, message ?? "unknow error."))
                }
                
                return
            }
            
            guard let encryptedToken = Crypto.encrypt(unlockedWallet.token.utf8) else {
                completion((nil, "Unable to decrypt your auth token."))
                return
            }
            
            updatedWallet.token = encryptedToken
            JMRPC.sharedInstance.command(method: .getaddress(jmWallet: updatedWallet, mixdepth: mixdepth), param: nil) { (response, errorDesc) in
                guard let response = response as? [String:Any],
                let address = response["address"] as? String else {
                    completion((nil, errorDesc ?? "unknown"))
                    return
                }

                completion((address, "message"))
            }
        }
    }
    
    static func coinjoin(wallet: Wallet,
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
        
//        var streamTask: URLSessionStreamTask!
//        let host = "xxx.onion"
//        let port = 28283
        
//        guard let decryptedToken = Crypto.decrypt(wallet.token),
//              let token = decryptedToken.utf8String else {
//                  completion((nil, "Unable to decrypt token."))
//                  return
//              }
        
//        let sesh = TorClient.sharedInstance.session
//        streamTask = sesh.streamTask(withHostName: host, port: port)
//        streamTask.resume()
//
//        func read() {
//            streamTask.readData(ofMinLength: 0, maxLength: 9999, timeout: 60) { (data, atEOF, error) in
//                guard let data = data,
//                let json = try? JSONSerialization.jsonObject(with: data, options: .mutableLeaves) as? [String:Any] else {
//                    print("streamTask data: \(data?.utf8String)")
//                    if let error = error {
//                        print("streamTask error: \(error.localizedDescription)")
//                    }
//                    read()
//
//                    return
//                }
//                print("streamTask json: \(json)")
//                read()
//            }
//        }
//
//        streamTask.write((token + "\r\n").data(using: .utf8)!, timeout: 20) { error in
//            if let error = error {
//                print("Failed to send: \(token)\n\(String(describing: error.localizedDescription))")
//            } else {
//                print("sent message: \(token)")
//                read()
//            }
//        }
        
        JMRPC.sharedInstance.command(method: .coinjoin(jmWallet: wallet), param: param) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                completion((nil, errorDesc ?? "unknown"))
                return
            }
            
            completion((response, errorDesc))
        }
    }
    
    static func stopTaker(wallet: Wallet, completion: @escaping ((response: [String:Any]?, message: String?)) -> Void) {
        JMRPC.sharedInstance.command(method: .takerStop(jmWallet: wallet), param: nil) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                completion((nil, errorDesc ?? "unknown"))
                return
            }
            
            completion((response, errorDesc))
        }
    }
    
    static func configGet(wallet: Wallet,
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
    
    static func configSet(wallet: Wallet,
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
    
    static func startMaker(wallet: Wallet, completion: @escaping ((response: [String:Any]?, message: String?)) -> Void) {
        let txfee = 0
        let cjfee_a = Int.random(in: 5000...10000)
        let cjfee_r = Double.random(in: 0.00002...0.000025)
        let minsize = Int.random(in: 99999...299999)
        let orderType = "sw0reloffer"
        
        let param:[String:Any] = [
            "txfee": txfee,
            "cjfee_a": cjfee_a,
            "cjfee_r": cjfee_r.avoidNotation,
            "ordertype": orderType,
            "minsize": minsize
        ]
                
        JMRPC.sharedInstance.command(method: .makerStart(jmWallet: wallet), param: param) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                      completion((nil, errorDesc ?? "unknown"))
                      return
                  }
            
            completion((response, errorDesc))
        }
    }
    
    static func stopMaker(wallet: Wallet, completion: @escaping ((response: [String:Any]?, message: String?)) -> Void) {
        JMRPC.sharedInstance.command(method: .makerStop(jmWallet: wallet), param: nil) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                completion((nil, errorDesc))
                return
            }
            
            completion((response, errorDesc))
        }
    }
    
    static func fidelityStatus(wallet: Wallet, completion: @escaping ((exists: Bool?, message: String?)) -> Void) {
        JMUtils.display(wallet: wallet) { (detail, message) in
            guard let detail = detail else {
                completion((nil, message))
                return
            }
            
            var exists = false
            
            for account in detail.accounts {
                if account.accountNumber == 0 {
                    for branch in account.branches {
                        if branch.balance > 0.0 {
                            for entry in branch.entries {
                                if entry.hd_path.contains(":") {
                                    print("funded timelocked address exists")
                                    exists = true
                                }
                            }
                        }
                    }
                }
            }
            completion((exists, nil))
        }
    }
    
    static func fidelityAddress(wallet: Wallet, date: String, completion: @escaping ((address: String?, message: String?)) -> Void) {
        JMRPC.sharedInstance.command(method: .gettimelockaddress(jmWallet: wallet, date: date), param: nil) { (response, errorDesc) in
            guard let dict = response as? [String:Any],
            let address = dict["address"] as? String else {
                completion((nil, errorDesc ?? "Unknown."))
                return
            }
            
            completion((address, errorDesc))
        }
    }
    
    static func wallets(completion: @escaping ((response: [String]?, message: String?)) -> Void) {
        JMRPC.sharedInstance.command(method: .walletall, param: nil) { (response, errorDesc) in
            guard let response = response as? [String:Any], let wallets = response["wallets"] as? [String] else {
                completion((nil, errorDesc))
                return }
            
            completion((wallets, nil))
        }
    }
    
    static func unfreezeFb(wallet: Wallet, completion: @escaping ((response: [String:Any]?, message: String?)) -> Void) {
        JMRPC.sharedInstance.command(method: .listutxos(jmWallet: wallet), param: nil) { (response, errorDesc) in
            guard let response = response as? [String:Any],
                    !response.isEmpty,
                    let utxos = response["utxos"] as? [[String:Any]],
                    !utxos.isEmpty else { return }
            
            var fbUtxo:JMUtxo?
            
            for (i, utxo) in utxos.enumerated() {
                let jmUtxo = JMUtxo(utxo)
                                
                if jmUtxo.frozen, let locktime = jmUtxo.locktime, locktime < Date() {
                    fbUtxo = jmUtxo
                }
                
                if i + 1 == utxos.count {
                    guard let fbUtxo = fbUtxo else {
                        print("no utxo")
                        completion((nil, "No frozen expired timelocked utxo."))
                        return
                    }
                    
                    let param:[String:Any] = [
                        "utxo-string":fbUtxo.utxoString,
                        "freeze": false
                    ]
                    
                    JMRPC.sharedInstance.command(method: .unfreeze(jmWallet: wallet), param: param) { (response, errorDesc) in
                        guard let response = response as? [String:Any] else {
                            completion((nil, errorDesc))
                            return
                        }
                        
                        completion((response, errorDesc))
                    }
                }
            }
        }
    }
    
    static func directSend(wallet: Wallet, address: String, amount: Int, mixdepth: Int, completion: @escaping ((jmTx: JMTx?, message: String?)) -> Void) {
        let param:[String:Any] = [
            "mixdepth":mixdepth,
            "amount_sats":amount,
            "destination": address
        ]
        
        JMRPC.sharedInstance.command(method: .directSend(jmWallet: wallet), param: param) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                completion((nil, errorDesc))
                return
            }
            
            completion((JMTx(response), errorDesc))
        }
    }
}
