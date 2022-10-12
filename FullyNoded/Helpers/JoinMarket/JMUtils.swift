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
        // First check that connection works...
        
        guard let passwordWords = Keys.seed() else { return }
        
        let arr = passwordWords.split(separator: " ")
        
        var password = ""
            
        for (i, word) in arr.enumerated() {
            if i <= 6 {
                password += word + " "
            }
        }
        
        let param:[String:Any] = [
            "walletname":"FullyNoded-\(randomString(length: 10)).jmdat",
            "password": password,
            "wallettype":"sw-fb"
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
                  let encryptedPass = Crypto.encrypt(password.utf8) else {
                      completion((nil, "Error encrypting jm wallet credentials."))
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
                    guard let descriptors = descriptors else {
                        completion((nil, "Error creating your jm descriptors."))
                        return
                    }
                                        
                    let accountMap:[String:Any] = [
                        "descriptor":descriptors[0],
                        "blockheight": blockheight,
                        "watching":Array(descriptors[2...descriptors.count - 1]),
                        "label":"Join Market"
                    ]
                                        
                    ImportWallet.accountMap(accountMap) { (success, errorDescription) in
                        guard success else {
                            completion((nil, errorDescription ?? "Unknown."))
                            return
                        }
                        
                        activeWallet(completion: { activeWallet in
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
    
    static func getSeed(wallet: JMWallet, completion: @escaping ((saved: Bool, message: String?)) -> Void) {
        JMRPC.sharedInstance.command(method: .getSeed(jmWallet: wallet), param: nil) { (response, errorDesc) in
            guard let dict = response as? [String:Any],
            let words = dict["seedphrase"] as? String else {
                completion((false, errorDesc))
                return
            }
            
            guard let encryptedWords = Crypto.encrypt(words.utf8) else {
                completion((false, "Unable to encrypt your seed words."))
                return
            }
            
            var updatedWallet:[String:Any] = [
                "words": encryptedWords,
                "name": wallet.name,
                "id": wallet.id,
                "index": Int16(0),
                "account": Int16(0),
                "fnWallet": "",
                "token": wallet.token,
                "password": wallet.password
            ]
            
            // check if it can be used with the current FN wallet?
            activeWallet { activeWallet in
                guard let activeWallet = activeWallet else {
                    completion((false, "No active wallet."))
                    return
                }
                
                guard let watching = activeWallet.watching, watching.count == 9 else {
                    recoverLocally(signer: words, walletDict: updatedWallet, completion: completion)
                    return
                }
                
                JMUtils.display(wallet: wallet) { (detail, message) in
                    guard let detail = detail else { return }
                    
                    let account = detail.accounts[4]
                    let lastBranch = account.branches[0]
                    let lastEntry = lastBranch.entries[4]
                    let address = lastEntry.address
                    
                    OnchainUtils.getAddressInfo(address: address) { (addressInfo, message) in
                        guard let addressInfo = addressInfo else {
                            completion((false, "Unable to get address info: \(message ?? "Unknown.")"))
                            return
                        }
                        
                        guard addressInfo.ismine else {
                            // RECOVER AS THE ACTIVE WALLET IS NOT THIS JM WALLET
                            recoverLocally(signer: words, walletDict: updatedWallet, completion: completion)
                            return
                        }
                        
                        updatedWallet["fnWallet"] = activeWallet.name
                        
                        guard let encryptedSigner = Crypto.encrypt(words.utf8) else {
                            completion((false, "Unable to encrypt the signer."))
                            return
                        }
                        
                        let dict:[String:Any] = ["id":UUID(), "words":encryptedSigner, "added":Date(), "label":"JM signer"]
                        
                        CoreDataService.saveEntity(dict: dict, entityName: .signers) { success in
                            guard success else {
                                completion((false, "Unable to save the encrypted signer."))
                                return
                            }
                            
                            CoreDataService.saveEntity(dict: updatedWallet, entityName: .jmWallets) { saved in
                                guard saved else {
                                    completion((false, "Unable to save your JMWallet locally."))
                                    return
                                }
                                
                                completion((true, nil))
                            }
                        }
                    }
                }
            }
        }
    }
    
    static func recoverLocally(signer: String, walletDict: [String:Any], completion: @escaping ((saved: Bool, message: String?)) -> Void) {
        var cointType = "0"
        let chain = UserDefaults.standard.object(forKey: "chain") as? String ?? "main"
        if chain != "main" {
            cointType = "1"
        }
        
        let blockheight = UserDefaults.standard.object(forKey: "blockheight") as? Int ?? 0
        
        guard let mk = Keys.masterKey(words: signer, coinType: cointType, passphrase: ""),
              let xfp = Keys.fingerprint(masterKey: mk) else {
                  completion((false, "Error deriving master key."))
                  return
              }
        
        JoinMarket.descriptors(mk, xfp) { descriptors in
            guard let descriptors = descriptors else {
                completion((false, "Error creating your jm descriptors."))
                return
            }
                                
            let accountMap:[String:Any] = [
                "descriptor":descriptors[0],
                "blockheight": blockheight,
                "watching":Array(descriptors[2...descriptors.count - 1]),
                "label":"Join Market"
            ]
                                            
            ImportWallet.accountMap(accountMap) { (success, errorDescription) in
                guard success else {
                    completion((false, errorDescription ?? "Unknown."))
                    return
                }
                
                activeWallet(completion: { activeWallet in
                    guard let activeWallet = activeWallet else {
                        return
                    }
                    
                    var updatedJmWallet:[String:Any] = walletDict
                    
                    updatedJmWallet["fnWallet"] = activeWallet.name
                    
                    CoreDataService.saveEntity(dict: updatedJmWallet, entityName: .jmWallets) { saved in
                        guard saved else {
                            completion((false, "Error saving jm wallet."))
                            return
                        }
                        
                        guard let encryptedSigner = Crypto.encrypt(signer.utf8) else {
                            completion((false, "Unable to encrypt the signer."))
                            return
                        }
                        
                        let dict:[String:Any] = ["id":UUID(), "words":encryptedSigner, "added":Date(), "label":"JM signer"]
                        
                        CoreDataService.saveEntity(dict: dict, entityName: .signers) { success in
                            guard success else {
                                completion((false, "Unable to save the encrypted signer."))
                                return
                            }
                            
                            completion((true, nil))
                        }
                    }
                })
            }
        }
    }
    
    static func recoverWallet(walletName: String, password: String, completion: @escaping ((recovered: Bool, message: String?)) -> Void) {
        guard let encryptedPassword = Crypto.encrypt(password.utf8) else {
            completion((false, "unable to encrypt jm wallet password."))
            return
        }
        
        var walletToUnlock:[String:Any] = [
            "password": encryptedPassword,
            "name": walletName,
            "id": UUID(),
            "account": Int16(0),
            "fnWallet":"",
            "index":Int16(0),
            "token": "".utf8,
            "words": "".utf8
        ]
        
        var jmWallet:JMWallet = JMWallet(walletToUnlock)
        
        JMRPC.sharedInstance.command(method: .unlockwallet(jmWallet: jmWallet), param: nil) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                completion((false, errorDesc ?? "Unknown."))
                return
            }
                        
            let walletUnlock = WalletUnlock(response)
            
            guard let updatedToken = Crypto.encrypt(walletUnlock.token.utf8) else {
                completion((false, "Unable to encrypt new token."))
                return
            }
            
            walletToUnlock["token"] = updatedToken
            jmWallet = JMWallet(walletToUnlock)
            
            JMUtils.getSeed(wallet: jmWallet) { (jmWalletSaved, message) in
                guard jmWalletSaved else {
                    completion((false, "There was an issue recovering that JM Wallet: \(message ?? "Unknown.")"))
                    return
                }
                
                completion((jmWalletSaved, nil))
            }
        }
    }
    
    static func display(wallet: JMWallet, completion: @escaping ((detail: WalletDetail?, message: String?)) -> Void) {
        JMRPC.sharedInstance.command(method: .walletdisplay(jmWallet: wallet), param: nil) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                completion((nil, errorDesc ?? "Unknown."))
                return
            }
            
            completion((WalletDetail(response), nil))
        }
    }
        
    static func syncIndexes(wallet: JMWallet, completion: @escaping ((String?)) -> Void) {
        JMUtils.display(wallet: wallet) { (detail, message) in
            guard let detail = detail else {
                completion((message ?? "Unknown."))
                return
            }
            
            var nextMixdepth = 0
            
            for (i, account) in detail.accounts.enumerated() {
                for branch in account.branches {
                    for entry in branch.entries {
                        if entry.amount > 0 {
                            let arr = entry.hd_path.split(separator: "/")
                            lastUsedIndex = Int("\(arr[arr.count - 1])")!
                            
                            if account.accountNumber < 4 {
                                nextMixdepth += 1
                            }
                        }
                    }
                }
                
                if i + 1 == detail.accounts.count {
                    CoreDataService.update(id: wallet.id, keyToUpdate: "account", newValue: Int16(nextMixdepth), entity: .jmWallets) { updated in
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
    
    static func getAddress(wallet: JMWallet, completion: @escaping ((address: String?, message: String?)) -> Void) {
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
            JMUtils.syncIndexes(wallet: updatedWallet) { message in
                JMRPC.sharedInstance.command(method: .getaddress(jmWallet: updatedWallet), param: nil) { (response, errorDesc) in
                    guard let response = response as? [String:Any],
                    let address = response["address"] as? String else {
                        completion((nil, errorDesc ?? "unknown"))
                        return
                    }

                    completion((address, "message"))
                }
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
    
    static func stopTaker(wallet: JMWallet, completion: @escaping ((response: [String:Any]?, message: String?)) -> Void) {
        JMRPC.sharedInstance.command(method: .takerStop(jmWallet: wallet), param: nil) { (response, errorDesc) in
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
    
    static func startMaker(wallet: JMWallet, completion: @escaping ((response: [String:Any]?, message: String?)) -> Void) {
        let txfee = Int.random(in: 250...550)
        let cjfee_a = Int.random(in: 400...650)
        let cjfee_r = Double.random(in: 0.0000189...0.000025)
        let minsize = Int.random(in: 99999...299999)
        let orderType = ["sw0reloffer", "sw0absoffer"].randomElement()!
        
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
    
    static func stopMaker(wallet: JMWallet, completion: @escaping ((response: [String:Any]?, message: String?)) -> Void) {
        JMRPC.sharedInstance.command(method: .makerStop(jmWallet: wallet), param: nil) { (response, errorDesc) in
            guard let response = response as? [String:Any] else {
                completion((nil, errorDesc))
                return
            }
            
            completion((response, errorDesc))
        }
    }
    
    static func fidelityStatus(wallet: JMWallet, completion: @escaping ((exists: Bool?, message: String?)) -> Void) {
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
    
    static func fidelityAddress(wallet: JMWallet, date: String, completion: @escaping ((address: String?, message: String?)) -> Void) {
        JMRPC.sharedInstance.command(method: .gettimelockaddress(jmWallet: wallet, date: date), param: nil) { (response, errorDesc) in
            guard let dict = response as? [String:Any],
            let address = dict["address"] as? String else {
                completion((nil, errorDesc ?? "Unknown."))
                return
            }
            
            // Need to import the address to FN wallet
            let fnWallet = wallet.fnWallet
            
            CoreDataService.retrieveEntity(entityName: .wallets) { fnWallets in
                guard let fnWallets = fnWallets, !fnWallets.isEmpty else {
                    return
                }
                
                // TODO: USE TIMELOCKED DESCRIPTOR INSTEAD
                let desc = "addr(\(address))"
                
                OnchainUtils.getDescriptorInfo(desc) { (descriptorInfo, message) in
                    guard let descInfo = descriptorInfo else { return }
                    
                    let newDesc = descInfo.descriptor
                    
                    for existingFnWallet in fnWallets {
                        let fnWalletStr = Wallet(dictionary: existingFnWallet)
                        var watching:[String] = []
                        
                        if fnWalletStr.watching != nil {
                            watching = fnWalletStr.watching!
                        }
                        
                        watching.append(newDesc)
                        
                        if fnWalletStr.name == fnWallet {
                            CoreDataService.update(id: fnWalletStr.id, keyToUpdate: "watching", newValue: watching, entity: .wallets) { saved in
                                // here we can import the address into core
                                let params = "[{\"desc\": \"\(newDesc)\", \"active\": false, \"timestamp\": \"now\", \"internal\": false, \"label\": \"JM Fidelity Bond Expiry \(date)\"}]"
                                
                                OnchainUtils.importDescriptors(params) { (imported, message) in
                                    completion((address, errorDesc))
                                }
                            }
                        }
                    }
                }
            }
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
    
    static func unfreezeFb(wallet: JMWallet, completion: @escaping ((response: [String:Any]?, message: String?)) -> Void) {
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
    
    static func directSend(wallet: JMWallet, address: String, amount: Int, mixdepth: Int, completion: @escaping ((jmTx: JMTx?, message: String?)) -> Void) {
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
