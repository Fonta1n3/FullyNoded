//
//  ImportWallet.swift
//  BitSense
//
//  Created by Peter on 16/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

class ImportWallet {
    
    static var index = 0
    static var processedWatching = [String]()
    static var isColdcard = false
            
    class func accountMap(_ accountMap: [String:Any], completion: @escaping ((success: Bool, errorDescription: String?)) -> Void) {
        var wallet = [String:Any]()
        var prefix = "FullyNoded"
        if isColdcard {
            prefix = "Coldcard"
        }
        var keypool = Bool()
        let descriptorParser = DescriptorParser()
        var primDescriptor = accountMap["descriptor"] as! String
        let blockheight = accountMap["blockheight"] as! Int
        let label = accountMap["label"] as! String
        let watching = accountMap["watching"] as? [String] ?? []
        
        wallet["label"] = label
        wallet["id"] = UUID()
        wallet["blockheight"] = Int64(blockheight)
        wallet["maxIndex"] = 2500
        wallet["index"] = 0
        
        let descStruct = descriptorParser.descriptor(primDescriptor)
        
        if descStruct.isMulti {
            wallet["type"] = "Multi-Sig"
            keypool = false
        } else {
            wallet["type"] = "Single-Sig"
            keypool = true
        }
        
        primDescriptor = primDescriptor.replacingOccurrences(of: "'", with: "h")
        let arr = primDescriptor.split(separator: "#")
        primDescriptor = "\(arr[0])"
        
        func createWalletNow(_ recDesc: String, _ changeDesc: String) {
            // Use the sha256 hash of the checksum-less primary receive keypool desc as the wallet name so it has a deterministic identifier
            let walletName = "\(prefix)-\(Crypto.sha256hash(primDescriptor))"
            createWallet(walletName: walletName) { (name, errorMessage) in
                if name != nil {
                    wallet["name"] = name
                    UserDefaults.standard.set(name, forKey: "walletName")
                    importReceiveDesc(recDesc: recDesc, label: label, keypool: keypool) { (success, errorMessage) in
                        if success {
                            importChangeDesc(changeDesc: changeDesc, keypool: keypool) { (success, errorMessage) in
                                if success {
                                    if watching.count > 0 {
                                        index = 0
                                        processedWatching.removeAll()
                                        importWatching(watching: watching) { (watchingArray, errorMessage) in
                                            if watchingArray != nil {
                                                wallet["watching"] = watchingArray
                                                rescan(wallet: wallet, completion: completion)
                                            } else {
                                                completion((false, "error importing watching descriptors: \(errorMessage ?? "unknown error importing watching descriptors")"))
                                            }
                                        }
                                    } else {
                                        rescan(wallet: wallet, completion: completion)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    completion((false, "error creatig wallet: \(errorMessage ?? "unknown error")"))
                }
            }
        }
        
        getDescriptorInfo(desc: primDescriptor) { (recDesc, errorMessage) in
            if recDesc != nil {
                wallet["receiveDescriptor"] = recDesc!
                
                getDescriptorInfo(desc: primDescriptor.replacingOccurrences(of: "/0/*", with: "/1/*")) { (changeDesc, errorMessage) in
                    if changeDesc != nil {
                        wallet["changeDescriptor"] = changeDesc!
                        let hash = Crypto.sha256hash(primDescriptor)
                        
                        walletExistsOnNode(hash) { (existingWallet) in
                            if existingWallet != nil {
                                wallet["name"] = existingWallet!
                                UserDefaults.standard.set(existingWallet!, forKey: "walletName")
                                
                                if watching.count > 0 {
                                    index = 0
                                    processedWatching.removeAll()
                                    
                                    processWatching(watching: watching) { (watchingArray, errorMessage) in
                                        if watchingArray != nil {
                                            wallet["watching"] = watchingArray!
                                            saveLocally(wallet: wallet, completion: completion)
                                        } else {
                                            completion((false, "error processing watching descriptors: \(errorMessage ?? "unknown error")"))
                                        }
                                    }
                                } else {
                                    saveLocally(wallet: wallet, completion: completion)
                                }
                            } else {
                                createWalletNow(recDesc!, changeDesc!)
                            }
                        }
                    } else {
                        completion((false, errorMessage ?? "error getting change descriptor info"))
                    }
                }
            } else {
                completion((false, errorMessage ?? "error getting descriptor info"))
            }
        }
        
    }
    
    class func coldcard(dict: [String:Any], completion: @escaping ((success: Bool, errorDescription: String?)) -> Void) {
        isColdcard = true
        /*
         ["xfp": 0F056943, "bip49": {
             "_pub" = upub5DMRSsh6mNaeiTXEzarZLvZezWp4cGhaDHjMz9iineDN8syqep2XHncDKFVtTUXY4fyKp12qDVVwdfq5rKkw2CDf5fy2gEHyh5NoTC6fiwm;
             deriv = "m/49'/1'/0'";
             first = 2NCAJ5wD4GvmW32GFLVybKPNphNU8UYoEJv;
             name = "p2wpkh-p2sh";
             xfp = FD3E8548;
             xpub = tpubDCDqt7XXvhAYY9HSwrCXB7BXqYM4RXB8WFtKgtTXGa6u3U6EV1NJJRFTcuTRyhSY5Vreg1LP8aPdyiAPQGrDJLikkHoc7VQg6DA9NtUxHtj;
         }, "xpub": tpubD6NzVbkrYhZ4XzL5Dhayo67Gorv1YMS7j8pRUvVMd5odC2LBPLAygka9p7748JtSq82FNGPppFEz5xxZUdasBRCqJqXvUHq6xpnsMcYJzeh, "bip44": {
             deriv = "m/44'/1'/0'";
             first = mtHSVByP9EYZmB26jASDdPVm19gvpecb5R;
             name = p2pkh;
             xfp = 92B53FD2;
             xpub = tpubDCiHGUNYdRRBPNYm7CqeeLwPWfeb2ZT2rPsk4aEW3eUoJM93jbBa7hPpB1T9YKtigmjpxHrB1522kSsTxGm9V6cqKqrp1EDaYaeJZqcirYB;
         }, "bip84": {
             "_pub" = vpub5Y5a91QvDT3yog4bmgbqFo7GPXpRpozogzQeDArSPzsY8SKGHTgjSswhxhGkRonUQ9tyo9ZSQ1ecLKkVUyewWEUJZdwgUQycvG86FV7sdhZ;
             deriv = "m/84'/1'/0'";
             first = tb1qupyd58ndsh7lut0et0vtrq432jvu9jtdyws9n9;
             name = p2wpkh;
             xfp = AB82D43E;
             xpub = tpubDC7jGaaSE66Pn4dgtbAAstde4bCyhSUs4r3P8WhMVvPByvcRrzrwqSvpF9Ghx83Z1LfVugGRrSBko5UEKELCz9HoMv5qKmGq3fqnnbS5E9r;
         }, "chain": XTN, "account": 0]
         */
        var wallet = [String:Any]()
        wallet["type"] = "Single-Sig"
        wallet["label"] = "Coldcard"
        wallet["id"] = UUID()
        wallet["blockheight"] = 0
        wallet["maxIndex"] = 2500
        wallet["index"] = 0
        
        let fingerprint = dict["xfp"] as! String
        
        let bip49 = dict["bip49"] as! NSDictionary
        let bipr49deriv = (bip49["deriv"] as! String).replacingOccurrences(of: "m", with: fingerprint)
        let bip49Xpub = (bip49["xpub"] as! String)
        let bip49DescPrim = "sh(wpkh([\(bipr49deriv.replacingOccurrences(of: "'", with: "h"))]\(bip49Xpub)/0/*))"
        let bip49DescChange = "sh(wpkh([\(bipr49deriv.replacingOccurrences(of: "'", with: "h"))]\(bip49Xpub)/1/*))"
        
        let bip44 = dict["bip44"] as! NSDictionary
        let bipr44deriv = (bip44["deriv"] as! String).replacingOccurrences(of: "m", with: fingerprint)
        let bip44Xpub = (bip44["xpub"] as! String)
        let bip44DescPrim = "pkh([\(bipr44deriv.replacingOccurrences(of: "'", with: "h"))]\(bip44Xpub)/0/*)"
        let bip44DescChange = "pkh([\(bipr44deriv.replacingOccurrences(of: "'", with: "h"))]\(bip44Xpub)/1/*)"
        
        let bip84 = dict["bip84"] as! NSDictionary
        let bipr84deriv = (bip84["deriv"] as! String).replacingOccurrences(of: "m", with: fingerprint)
        let bip84Xpub = (bip84["xpub"] as! String)
        let bip84DescPrim = "wpkh([\(bipr84deriv.replacingOccurrences(of: "'", with: "h"))]\(bip84Xpub)/0/*)"
        
        let watching = [bip49DescPrim, bip49DescChange, bip44DescPrim, bip44DescChange]
        wallet["descriptor"] = bip84DescPrim
        wallet["watching"] = watching
        accountMap(wallet, completion: completion)
    }
    
    class func createWallet(walletName: String, completion: @escaping ((name: String?, errorMessage: String?)) -> Void) {
        let param = "\"\(walletName)\", true, true, \"\", true"
        Reducer.makeCommand(command: .createwallet, param: param) { (response, errorMessage) in
            if let dict = response as? NSDictionary {
                if let name = dict["name"] as? String {
                    completion((name, nil))
                } else {
                    completion((nil, errorMessage))
                }
            } else {
                completion((nil, errorMessage))
            }
        }
    }
    
    class func importReceiveDesc(recDesc: String, label: String, keypool: Bool, completion: @escaping ((success: Bool, errorMessage: String?)) -> Void) {
        let recParams = "[{ \"desc\": \"\(recDesc)\", \"timestamp\": \"now\", \"range\": [0,2500], \"watchonly\": true, \"label\": \"\(label)\", \"keypool\": \(keypool), \"internal\": false }], {\"rescan\": false}"
        importMultiDesc(params: recParams, completion: completion)
    }
    
    class func importChangeDesc(changeDesc: String, keypool: Bool, completion: @escaping ((success: Bool, errorMessage: String?)) -> Void) {
        let changeParams = "[{ \"desc\": \"\(changeDesc)\", \"timestamp\": \"now\", \"range\": [0,2500], \"watchonly\": true, \"keypool\": \(keypool), \"internal\": true }], {\"rescan\": false}"
        importMultiDesc(params: changeParams, completion: completion)
    }
    
    class func walletExistsOnNode(_ hash: String, completion: @escaping ((String?)) -> Void) {
        Reducer.makeCommand(command: .listwalletdir, param: "") { (response, errorMessage) in
            if let dict = response as? NSDictionary {
                parseWallets(wallets: dict, hash: hash, completion: completion)
            } else {
                completion(nil)
            }
        }
    }
    
    class func parseWallets(wallets: NSDictionary, hash: String, completion: @escaping ((String?)) -> Void) {
        let walletArr = wallets["wallets"] as! NSArray
        var existingWallet: String?
        for (i, wallet) in walletArr.enumerated() {
            let walletDict = wallet as! NSDictionary
            let walletName = walletDict["name"] as! String
            if walletName.contains(hash) {
                existingWallet = walletName
            }
            if i + 1 == walletArr.count {
                completion(existingWallet)
            }
        }
    }
    
    class func doesWalletExistLocally(walletToBe: [String:Any], completion: @escaping ((Bool)) -> Void) {
        let walletToBeStruct = Wallet(dictionary: walletToBe)
        CoreDataService.retrieveEntity(entityName: .wallets) { (wallets) in
            var walletExists = false
            if wallets != nil {
                if wallets!.count > 0 {
                    for (i, wallet) in wallets!.enumerated() {
                        let walletStruct = Wallet(dictionary: wallet)
                        if walletStruct.name == walletToBeStruct.name {
                            walletExists = true
                        }
                        if i + 1 == wallets!.count {
                            completion(walletExists)
                        }
                    }
                } else {
                    completion(false)
                }
            } else {
                completion(false)
            }
        }
    }
    
    class func getDescriptorInfo(desc: String, completion: @escaping ((desc: String?, errorMessage: String?)) -> Void) {
        Reducer.makeCommand(command: .getdescriptorinfo, param: "\"\(desc)\"") { (response, errorMessage) in
            if let dict = response as? NSDictionary {
                if let updatedDescriptor = dict["descriptor"] as? String {
                    completion((updatedDescriptor, nil))
                }
            } else {
                completion((nil, errorMessage ?? "error getting descriptor info"))
            }
        }
    }
    
    class func saveLocally(wallet: [String:Any], completion: @escaping ((success: Bool, errorDescription: String?)) -> Void) {
        doesWalletExistLocally(walletToBe: wallet) { (exists) in
            if exists {
                completion((false, "That wallet already exists!"))
            } else {
                CoreDataService.saveEntity(dict: wallet, entityName: .wallets) { (success) in
                    if success {
                        completion((true, nil))
                    } else {
                        completion((false, "error saving wallet locally"))
                    }
                }
            }
        }
    }
    
    class func rescan(wallet: [String:Any], completion: @escaping ((success: Bool, errorDescription: String?)) -> Void) {
        Reducer.makeCommand(command: .getblockchaininfo, param: "") { (response, errorMessage) in
            if let dict = response as? NSDictionary {
                if let pruned = dict["pruned"] as? Bool {
                    if pruned {
                        if let pruneHeight = dict["pruneheight"] as? Int {
                            Reducer.makeCommand(command: .rescanblockchain, param: "\(pruneHeight)") { (_, _) in }
                            saveLocally(wallet: wallet, completion: completion)
                        } else {
                            completion((false, errorMessage ?? "error getting prune height"))
                        }
                    } else {
                        Reducer.makeCommand(command: .rescanblockchain, param: "") { (_, _) in }
                        saveLocally(wallet: wallet, completion: completion)
                    }
                } else {
                    completion((false, errorMessage ?? "error getting prune info"))
                }
            } else {
                 completion((false, errorMessage ?? "error getting blockchain info"))
            }
        }
    }
    
    class func importMultiDesc(params: String, completion: @escaping ((success: Bool, errorMessage: String?)) -> Void) {
        Reducer.makeCommand(command: .importmulti, param: params) { (response, errorDescription) in
            if let result = response as? NSArray {
                if result.count > 0 {
                    if let dict = result[0] as? NSDictionary {
                        if let success = dict["success"] as? Bool {
                            completion((success, nil))
                        } else {
                            completion((false, errorDescription ?? "unknown error importing your keys"))
                        }
                    }
                } else {
                    completion((false, errorDescription ?? "unknown error importing your keys"))
                }
            } else {
                completion((false, errorDescription ?? "unknown error importing your keys"))
            }
        }
    }
    
    class func importWatching(watching: [String], completion: @escaping ((watchingArray: [String]?, errorMessage: String?)) -> Void) {
        if index < watching.count {
            getDescriptorInfo(desc: watching[index]) { (desc, errMessage) in
                if desc != nil {
                    let params = "[{ \"desc\": \"\(desc!)\", \"timestamp\": \"now\", \"range\": [0,2500], \"watchonly\": true, \"label\": \"watching\", \"keypool\": false, \"internal\": false }], {\"rescan\": false}"
                    importMultiDesc(params: params) { (success, errorMessage) in
                        if success {
                            processedWatching.append(desc!)
                            index += 1
                            importWatching(watching: watching, completion: completion)
                        } else {
                            completion((nil, "Error importing descriptor: \(errorMessage ?? "unknown error")"))
                        }
                    }
                } else {
                    completion((nil, errMessage))
                }
            }
        } else {
            completion((processedWatching, nil))
        }
    }
    
    class func processWatching(watching: [String], completion: @escaping ((watchingArray: [String]?, errorMessage: String?)) -> Void) {
        if index < watching.count {
            getDescriptorInfo(desc: watching[index]) { (desc, errMessage) in
                if desc != nil {
                    processedWatching.append(desc!)
                    index += 1
                    processWatching(watching: watching, completion: completion)
                } else {
                    completion((nil, errMessage))
                }
            }
        } else {
            completion((processedWatching, nil))
        }
    }
    
}
