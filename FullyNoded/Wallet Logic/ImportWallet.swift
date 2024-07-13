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
    static var version:Int = 0
    static var isHot = false
            
    class func accountMap(_ accountMap: [String:Any], completion: @escaping ((success: Bool, errorDescription: String?)) -> Void) {
        let password = accountMap["password"] as? String ?? ""
        var wallet = [String:Any]()
        var prefix = "FullyNoded"
        if isColdcard {
            prefix = "Coldcard"
        }
        var primDescriptor = accountMap["descriptor"] as! String
        let blockheight = accountMap["blockheight"] as? Int ?? 0
        let label = accountMap["label"] as! String
        let watching = accountMap["watching"] as? [String] ?? []
        
        wallet["label"] = label
        wallet["id"] = UUID()
        wallet["blockheight"] = Int64(blockheight)
        wallet["maxIndex"] = 999
        wallet["index"] = 0
        
        var descStruct = Descriptor(primDescriptor)
        isHot = descStruct.isHot
        
        guard let version = UserDefaults.standard.object(forKey: "version") as? Int else {
            completion((false, "Version unknown. In order to create a wallet we need to know which version of Bitcoin Core you are running, please go the the home screen and refresh then try to create this wallet again."))
            
            return
        }
        
        self.version = version
        
        if self.version >= 210100 {
            wallet["type"] = "Native-Descriptor"
        }
        
        primDescriptor = primDescriptor.replacingOccurrences(of: "'", with: "h")
        let arr = primDescriptor.split(separator: "#")
        primDescriptor = "\(arr[0])"
        descStruct = Descriptor(primDescriptor)
        
        // If the descriptor is multisig, we sort the keys lexicographically
        if descStruct.isMulti {
            var dictArray = [[String:String]]()
            
            for keyWithPath in descStruct.keysWithPath {                
                if keyWithPath.contains("]") {
                    let keyPathArr = keyWithPath.split(separator: "]")
                    
                    if keyPathArr.count > 0 {
                        var key = "\(keyPathArr[1])"
                        
                        if key.contains(")") {
                            key = key.replacingOccurrences(of: ")", with: "")
                        }
                        
                        //add range to each key
                        if !key.contains("/0/*") {
                            key += "/0/*"
                        }
                        
                        let dict = ["path":"\(keyPathArr[0])]", "key": key]
                        dictArray.append(dict)
                    }
                } else {
                    var key = keyWithPath
                    
                    if key.contains(")") {
                        key = key.replacingOccurrences(of: ")", with: "")
                    }
                    
                    //add range to each key
                    if !key.contains("/0/*") {
                        key += "/0/*"
                    }
                    
                    let dict = ["path":"", "key": key]
                    dictArray.append(dict)
                }
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
        
        func createWalletNow(_ recDesc: String, _ changeDesc: String, _ password: String) {
            // Use the sha256 hash of the checksum-less primary receive keypool desc as the wallet name so it has a deterministic identifier
            let walletName = "\(prefix)-\(Crypto.sha256hash(primDescriptor))"
            
            createWallet(walletName, password) { (name, errorMessage) in
                guard let name = name else {
                    UserDefaults.standard.removeObject(forKey: "walletName")
                    completion((false, "error creatig wallet: \(errorMessage ?? "unknown error")"))
                    return
                }
                
                wallet["name"] = name
                UserDefaults.standard.set(wallet["name"] as! String, forKey: "walletName")
                
                if version >= 210100 {
                    importPrimaryDescriptors(recDesc, changeDesc) { (success, errorMessage) in
                        guard success else {
                            UserDefaults.standard.removeObject(forKey: "walletName")
                            completion((false, "error importing descriptor: \(errorMessage ?? "unknown error")"))
                            return
                        }
                        
                        if watching.count > 0 {
                            self.processWatching(watching: watching) { (watchingArray, errorMessage) in
                                guard let watchingArray = watchingArray, watchingArray.count > 0 else {
                                    UserDefaults.standard.removeObject(forKey: "walletName")
                                    completion((false, "Error processing watching descriptors: \(errorMessage ?? "unknown")"))
                                    return
                                }
                                
                                var params = ["requests":[]]
                                
                                for (i, watchingDesc) in watchingArray.enumerated() {
                                    var ischange = false
                                    
                                    if watchingDesc.contains("/1/") {
                                        ischange = true
                                    }
                                    
                                    let param_dict = [
                                        "desc": watchingDesc,
                                        "active": false,
                                        "range": [0,999],
                                        "next_index": 0,
                                        "timestamp": "now",
                                        "internal": ischange
                                    ]
                                                                        
                                    params["requests"]?.append(param_dict)
                                                                        
                                    if i + 1 == watchingArray.count {
                                        let param:Import_Descriptors = .init(params)
                                        self.importDescriptors(param) { (success, errorMessage) in
                                            if success {
                                                wallet["watching"] = watchingArray
                                                //rescan(wallet: wallet, completion: completion)
                                                saveLocally(wallet: wallet, completion: completion)
                                            } else {
                                                UserDefaults.standard.removeObject(forKey: "walletName")
                                                completion((false, "Error importing watching descriptors: \(errorMessage ?? "unknown")"))
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            //rescan(wallet: wallet, completion: completion)
                            saveLocally(wallet: wallet, completion: completion)
                        }
                    }
                } else {
                    completion((false, "Fully Noded works with Bitcoin Core 0.21 minimum."))
                }
            }
        }
        
        getDescriptorInfo(desc: primDescriptor) { (recDesc, errorMessage) in
            guard let recDesc = recDesc else {
                UserDefaults.standard.removeObject(forKey: "walletName")
                completion((false, errorMessage ?? "error getting descriptor info"))
                return
            }
            
            wallet["receiveDescriptor"] = recDesc.replacingOccurrences(of: "'", with: "h")
            
            getDescriptorInfo(desc: primDescriptor.replacingOccurrences(of: "/0/*", with: "/1/*")) { (changeDesc, errorMessage) in
                guard let changeDesc = changeDesc else {
                    UserDefaults.standard.removeObject(forKey: "walletName")
                    completion((false, errorMessage ?? "error getting change descriptor info"))
                    return
                }
                
                wallet["changeDescriptor"] = changeDesc.replacingOccurrences(of: "'", with: "h")
                let hash = Crypto.sha256hash(primDescriptor)
                
                walletExistsOnNode(hash) { existingWallet in
                    guard let existingWallet = existingWallet else {
                        createWalletNow(recDesc, changeDesc, password)
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
        wallet["maxIndex"] = 999
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
    
    class func createWallet(_ walletName: String, _ password: String, completion: @escaping ((name: String?, errorMessage: String?)) -> Void) {
        let param = [
            "wallet_name":walletName,
            "avoid_reuse":true,
            "descriptors":true,
            "passphrase":password,
            "load_on_startup":true,
            "disable_private_keys":!isHot
        ] as [String:Any]
        
        
        OnchainUtils.createWallet(param: .init(param)) { (name, message) in
            if password != "" {
                UserDefaults.standard.setValue(name, forKey: "walletName")
                let param:Wallet_Passphrase = .init(["passphrase":password, "timeout":600])
                Reducer.sharedInstance.makeCommand(command: .walletpassphrase(param: param)) { (response, errorMessage) in
                    if errorMessage == nil {
                        completion((name, message))
                    } else {
                        completion((nil, errorMessage ?? "Unknown error unlocking your wallet."))
                    }
                }
            } else {
                completion((name, message))
            }
        }
    }
    
    class func importPrimaryDescriptors(_ recDesc: String, _ changeDesc: String, completion: @escaping ((success: Bool, errorMessage: String?)) -> Void) {
        var recDescIsActive = true
        var changeDescIsActive = true
        
        if recDesc.hasPrefix("combo") {
            recDescIsActive = false
        }
        
        if changeDesc.hasPrefix("combo") {
            changeDescIsActive = false
        }
        
        let params:Import_Descriptors = .init([
            "requests":
                [
                    ["desc": recDesc,
                     "active": recDescIsActive,
                     "range": [0,999],
                     "next_index": 0,
                     "timestamp": "now",
                     "internal": false
                    ],
                    [
                        "desc": changeDesc,
                        "active": changeDescIsActive,
                        "range": [0,999],
                        "next_index": 0,
                        "timestamp": "now",
                        "internal": true
                    ]
                ]
        ] as [String:Any])
        
        importDescriptors(params, completion: completion)
    }
    
    class func importDescriptors(_ params: Import_Descriptors, completion: @escaping ((success: Bool, errorMessage: String?)) -> Void) {
        OnchainUtils.importDescriptors(params) { (imported, message) in
            completion((imported, message))
        }        
    }
    
    class func walletExistsOnNode(_ hash: String, completion: @escaping ((String?)) -> Void) {
        OnchainUtils.listWalletDir { (walletDir, message) in
            if let walletDir = walletDir {
                parseWallets(walletDir.wallets, hash, completion: completion)
            } else {
                completion(nil)
            }
        }
    }
    
    class func parseWallets(_ wallets: [String], _ hash: String, completion: @escaping ((String?)) -> Void) {
        guard !wallets.isEmpty else {
            completion(nil)
            return
        }
        
        var existingWallet: String?
        
        for (i, walletName) in wallets.enumerated() {
            if walletName.contains(hash) {
                existingWallet = walletName
            }
            
            if i + 1 == wallets.count {
                completion(existingWallet)
            }
        }
    }
    
    class func getDescriptorInfo(desc: String, completion: @escaping ((desc: String?, errorMessage: String?)) -> Void) {
        let param:Get_Descriptor_Info = .init(["descriptor":desc])
        OnchainUtils.getDescriptorInfo(param) { (descriptorInfo, message) in
            guard let descriptorInfo = descriptorInfo else {
                completion((nil, message))
                return
            }
            let descStruct = Descriptor(desc)
            completion((desc + "#" + descriptorInfo.checksum, message))
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
                if existingWallet["id"] != nil {
                    let existingWalletStr = Wallet(dictionary: existingWallet)
                    alreadySaved = existingWalletStr.name == walletToSave.name
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
        let walletStr = Wallet(dictionary: wallet)
        OnchainUtils.getBlockchainInfo { (blockchainInfo, message) in
            guard let blockchainInfo = blockchainInfo else {
                saveLocally(wallet: wallet, completion: completion)
                return
            }
            
            if blockchainInfo.pruned {
                OnchainUtils.rescanNow(from: blockchainInfo.pruneheight) { (started, message) in
                    saveLocally(wallet: wallet, completion: completion)
                }
            } else {
                OnchainUtils.rescanNow(from: walletStr.blockheight) { (started, message) in
                    saveLocally(wallet: wallet, completion: completion)
                }
            }
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
