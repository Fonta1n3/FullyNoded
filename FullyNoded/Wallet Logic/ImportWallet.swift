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
    static var isRecovering = false
            
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
        
        var descStruct = descriptorParser.descriptor(primDescriptor)
        
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
        descStruct = descriptorParser.descriptor(primDescriptor)
        
        // If the descriptor is multisig, we sort the keys lexicographically
        if descStruct.isMulti {
            var dictArray = [[String:String]]()
            
            for keyWithPath in descStruct.keysWithPath {
                let arr = keyWithPath.split(separator: "]")
                var key = "\(arr[1])"
                
                if key.contains(")") {
                    key = key.replacingOccurrences(of: ")", with: "")
                }
                
                //add range to each key
                if !key.contains("/0/*") {
                    key += "/0/*"
                }
                
                let dict = ["path":"\(arr[0])]", "key": key]
                dictArray.append(dict)
            }
            
            dictArray.sort(by: {($0["key"]!) < $1["key"]!})
            
            var sortedKeys = ""
            
            for (i, sortedItem) in dictArray.enumerated() {
                let path = sortedItem["path"]!
                let key = sortedItem["key"]!
                let fullKey = path + key
                sortedKeys += fullKey
                
                if i + 1 < dictArray.count {
                    sortedKeys += ","
                }
            }
            
            let arr2 = primDescriptor.split(separator: ",")
            
            primDescriptor = "\(arr2[0])," + sortedKeys + "))"
            
            if primDescriptor.hasPrefix("sh(wsh") {
                primDescriptor += ")"
            }
        }
        
        func createWalletNow(_ recDesc: String, _ changeDesc: String) {
            // Use the sha256 hash of the checksum-less primary receive keypool desc as the wallet name so it has a deterministic identifier
            let walletName = "\(prefix)-\(Crypto.sha256hash(primDescriptor))"
            
            createWallet(walletName) { (name, errorMessage) in
                guard let name = name else {
                    UserDefaults.standard.removeObject(forKey: "walletName")
                    completion((false, "error creatig wallet: \(errorMessage ?? "unknown error")"))
                    return
                }
                
                wallet["name"] = name
                UserDefaults.standard.set(wallet["name"] as! String, forKey: "walletName")
                
                importReceiveDesc(recDesc, label, keypool) { (success, errorMessage) in
                    guard success else {
                        UserDefaults.standard.removeObject(forKey: "walletName")
                        completion((false, "error importing receive descriptor: \(errorMessage ?? "unknown error")"))
                        return
                    }
                    
                    importChangeDesc(changeDesc, keypool) { (success, errorMessage) in
                        guard success else {
                            UserDefaults.standard.removeObject(forKey: "walletName")
                            completion((false, "error importing change descriptor: \(errorMessage ?? "unknown error")"))
                            return
                        }
                        
                        if watching.count > 0 {
                            index = 0
                            processedWatching.removeAll()
                            
                            importWatching(watching: watching) { (watchingArray, errorMessage) in
                                guard let watchingArray = watchingArray else {
                                    UserDefaults.standard.removeObject(forKey: "walletName")
                                    completion((false, "error importing watching descriptors: \(errorMessage ?? "unknown error importing watching descriptors")"))
                                    return
                                }
                                
                                wallet["watching"] = watchingArray
                                rescan(wallet: wallet, completion: completion)
                            }
                        } else {
                            rescan(wallet: wallet, completion: completion)
                        }
                    }
                }
            }
        }
        
        getDescriptorInfo(desc: primDescriptor) { (recDesc, errorMessage) in
            guard let recDesc = recDesc else {
                UserDefaults.standard.removeObject(forKey: "walletName")
                completion((false, errorMessage ?? "error getting descriptor info"))
                return
            }
            
            wallet["receiveDescriptor"] = recDesc
            
            getDescriptorInfo(desc: primDescriptor.replacingOccurrences(of: "/0/*", with: "/1/*")) { (changeDesc, errorMessage) in
                guard let changeDesc = changeDesc else {
                    UserDefaults.standard.removeObject(forKey: "walletName")
                    completion((false, errorMessage ?? "error getting change descriptor info"))
                    return
                }
                
                wallet["changeDescriptor"] = changeDesc
                let hash = Crypto.sha256hash(primDescriptor)
                
                walletExistsOnNode(hash) { existingWallet in
                    guard let existingWallet = existingWallet else {
                        createWalletNow(recDesc, changeDesc)
                        return
                    }
                    
                    wallet["name"] = existingWallet
                    UserDefaults.standard.set(wallet["name"] as! String, forKey: "walletName")
                    
                    if watching.count > 0 {
                        index = 0
                        processedWatching.removeAll()
                        
                        processWatching(watching: watching) { (watchingArray, errorMessage) in
                            guard let watchingArray = watchingArray else {
                                UserDefaults.standard.removeObject(forKey: "walletName")
                                completion((false, "error processing watching descriptors: \(errorMessage ?? "unknown error")"))
                                return
                            }
                            
                            wallet["watching"] = watchingArray
                            saveLocally(wallet: wallet, completion: completion)
                        }
                    } else {
                        saveLocally(wallet: wallet, completion: completion)
                    }
                }
            }
        }
    }
    
    class func coldcard(dict: [String:Any], completion: @escaping ((success: Bool, errorDescription: String?)) -> Void) {
        isColdcard = true

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
    
    class func createWallet(_ walletName: String, completion: @escaping ((name: String?, errorMessage: String?)) -> Void) {
        let param = "\"\(walletName)\", true, true, \"\", true"
        Reducer.makeCommand(command: .createwallet, param: param) { (response, errorMessage) in
            guard let dict = response as? NSDictionary, let name = dict["name"] as? String else {
                completion((nil, errorMessage))
                return
            }
            
            completion((name, nil))
        }
    }
    
    class func importReceiveDesc(_ recDesc: String, _ label: String, _ keypool: Bool, completion: @escaping ((success: Bool, errorMessage: String?)) -> Void) {
        let recParams = "[{ \"desc\": \"\(recDesc)\", \"timestamp\": \"now\", \"range\": [0,2500], \"watchonly\": true, \"label\": \"\(label)\", \"keypool\": \(keypool), \"internal\": false }], {\"rescan\": false}"
        
        importMultiDesc(params: recParams, completion: completion)
    }
    
    class func importChangeDesc(_ changeDesc: String, _ keypool: Bool, completion: @escaping ((success: Bool, errorMessage: String?)) -> Void) {
        let changeParams = "[{ \"desc\": \"\(changeDesc)\", \"timestamp\": \"now\", \"range\": [0,2500], \"watchonly\": true, \"keypool\": \(keypool), \"internal\": true }], {\"rescan\": false}"
        
        importMultiDesc(params: changeParams, completion: completion)
    }
    
    class func walletExistsOnNode(_ hash: String, completion: @escaping ((String?)) -> Void) {
        Reducer.makeCommand(command: .listwalletdir, param: "") { (response, errorMessage) in
            if let wallets = response as? NSDictionary {
                parseWallets(wallets, hash, completion: completion)
            } else {
                completion(nil)
            }
        }
    }
    
    class func parseWallets(_ wallets: NSDictionary, _ hash: String, completion: @escaping ((String?)) -> Void) {
        guard let walletArr = wallets["wallets"] as? NSArray, walletArr.count > 0 else {
            completion(nil)
            return
        }
        
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
    
    class func getDescriptorInfo(desc: String, completion: @escaping ((desc: String?, errorMessage: String?)) -> Void) {
        Reducer.makeCommand(command: .getdescriptorinfo, param: "\"\(desc)\"") { (response, errorMessage) in
            guard let dict = response as? NSDictionary, let updatedDescriptor = dict["descriptor"] as? String else {
                completion((nil, errorMessage ?? "error getting descriptor info"))
                return
            }
            
            completion((updatedDescriptor, nil))
        }
    }
    
    class func saveLocally(wallet: [String:Any], completion: @escaping ((success: Bool, errorDescription: String?)) -> Void) {
        let walletToSave = Wallet(dictionary: wallet)
        
        func save() {
            CoreDataService.saveEntity(dict: wallet, entityName: .wallets) { (success) in
                if success {
                    completion((true, nil))
                } else {
                    completion((false, "error saving wallet locally"))
                }
            }
        }
        
        CoreDataService.retrieveEntity(entityName: .wallets) { wallets in
            guard let wallets = wallets, wallets.count > 0 else {
                save()
                return
            }
            
            var alreadySaved = false
            
            for (i, existingWallet) in wallets.enumerated() {
                let existingWalletStr = Wallet(dictionary: existingWallet)
                
                if existingWalletStr.receiveDescriptor == walletToSave.receiveDescriptor {
                    alreadySaved = true
                }
                
                if i + 1 == wallets.count {
                    if !alreadySaved {
                        save()
                    } else {
                        completion((true, nil))
                    }
                }
            }
        }
    }
    
    class func rescan(wallet: [String:Any], completion: @escaping ((success: Bool, errorDescription: String?)) -> Void) {
        if !isRecovering {
            Reducer.makeCommand(command: .getblockchaininfo, param: "") { (response, errorMessage) in
                guard let dict = response as? NSDictionary, let pruned = dict["pruned"] as? Bool else {
                    completion((false, errorMessage ?? "error getting blockchain info"))
                    return
                }
                
                if pruned {
                    guard let pruneHeight = dict["pruneheight"] as? Int else {
                        completion((false, errorMessage ?? "error getting prune height"))
                        return
                    }
                    
                    Reducer.makeCommand(command: .rescanblockchain, param: "\(pruneHeight)") { (_, _) in }
                    saveLocally(wallet: wallet, completion: completion)
                } else {
                    Reducer.makeCommand(command: .rescanblockchain, param: "") { (_, _) in }
                    saveLocally(wallet: wallet, completion: completion)
                }
            }
        } else {
            saveLocally(wallet: wallet, completion: completion)
        }
    }
    
    class func importMultiDesc(params: String, completion: @escaping ((success: Bool, errorMessage: String?)) -> Void) {
        Reducer.makeCommand(command: .importmulti, param: params) { (response, errorDescription) in
            guard let result = response as? NSArray, result.count > 0,
                let dict = result[0] as? NSDictionary,
                let success = dict["success"] as? Bool,
                success else {
                    completion((false, errorDescription ?? "unknown error importing your keys"))
                    return
            }
            
            completion((success, nil))
        }
    }
    
    class func importWatching(watching: [String], completion: @escaping ((watchingArray: [String]?, errorMessage: String?)) -> Void) {
        if index < watching.count {
            getDescriptorInfo(desc: watching[index]) { (desc, errMessage) in
                guard let desc = desc else {
                    completion((nil, errMessage))
                    return
                }
                
                let params = "[{ \"desc\": \"\(desc)\", \"timestamp\": \"now\", \"range\": [0,2500], \"watchonly\": true, \"label\": \"watching\", \"keypool\": false, \"internal\": false }], {\"rescan\": false}"
                importMultiDesc(params: params) { (success, errorMessage) in
                    if success {
                        processedWatching.append(desc)
                        index += 1
                        importWatching(watching: watching, completion: completion)
                    } else {
                        completion((nil, "Error importing descriptor: \(errorMessage ?? "unknown error")"))
                    }
                }
            }
        } else {
            completion((processedWatching, nil))
        }
    }
    
    class func processWatching(watching: [String], completion: @escaping ((watchingArray: [String]?, errorMessage: String?)) -> Void) {
        if index < watching.count {
            getDescriptorInfo(desc: watching[index]) { (desc, errMessage) in
                guard let desc = desc else {
                    completion((nil, errMessage))
                    return
                }
                
                processedWatching.append(desc)
                index += 1
                processWatching(watching: watching, completion: completion)
            }
        } else {
            completion((processedWatching, nil))
        }
    }
    
}
