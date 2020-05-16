//
//  FirstTime.swift
//  BitSense
//
//  Created by Peter on 05/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

class FirstTime {
    
    class func firstTimeHere(completion: @escaping ((Bool)) -> Void) {
        let cd = CoreDataService()
        var newNode = [String:Any]()
        var newWallet = [String:Any]()
        var newDescriptor = [String:Any]()
        let aesService = AESService()
        
        func encrypt(_ data: Data) -> Data? {
            var encryptedValue:Data?
            Crypto.encryptData(dataToEncrypt: data) { encryptedData in
                if encryptedData != nil {
                    encryptedValue = encryptedData
                }
            }
            return encryptedValue
        }
        
        func saveNewDescriptor(descriptor: [String:Any]) {
            cd.saveEntity(dict: descriptor, entityName: .newDescriptors) {
                if !cd.boolToReturn {
                    completion(false)
                }
            }
        }
        
        func loopThroughOldDescriptorKeyPairs(oldDescriptor: [String:Any]) {
            for (key, value) in oldDescriptor {
                if key != "id" && key != "nodeID" {
                    let decryptedKey = aesService.decryptOldKey(keyToDecrypt: value as! String)
                    switch key {
                    case "descriptor":
                        let encryptedData = encrypt(decryptedKey.dataUsingUTF8StringEncoding)
                        newDescriptor["descriptor"] = encryptedData
                    case "label":
                        newDescriptor["label"] = decryptedKey
                    case "range":
                        newDescriptor["range"] = decryptedKey
                    default:
                        break
                    }
                }
            }
        }
        
        func loopThroughOldDescriptors(oldDescriptors: [[String:Any]]) {
            for (i, oldDescriptor) in oldDescriptors.enumerated() {
                newDescriptor["id"] = UUID()
                loopThroughOldDescriptorKeyPairs(oldDescriptor: oldDescriptor)
                saveNewDescriptor(descriptor: newDescriptor)
                if i + 1 == oldDescriptors.count {
                    completion(true)
                }
            }
        }
        
        func convertOldDescriptors() {
            cd.retrieveEntity(entityName: .oldDescriptors) {
                let oldDescriptors = cd.entities
                if oldDescriptors.count > 0 {
                    loopThroughOldDescriptors(oldDescriptors: oldDescriptors)
                } else {
                    completion(true)
                }
            }
        }
        
        func saveNewWallet(wallet: [String:Any]) {
            cd.saveEntity(dict: wallet, entityName: .newHdWallets) {
                if !cd.boolToReturn {
                    completion(false)
                }
            }
        }
        
        func loopThroughOldWalletKeyPairs(oldWallet: [String:Any]) {
            for (key, value) in oldWallet {
                if key != "id" && key != "nodeID" {
                    let decryptedKey = aesService.decryptOldKey(keyToDecrypt: value as! String)
                    switch key {
                    case "descriptor":
                        let encryptedData = encrypt(decryptedKey.dataUsingUTF8StringEncoding)
                        newWallet["descriptor"] = encryptedData
                    case "index":
                        newWallet["index"] = Int32(decryptedKey)
                    case "label":
                        newWallet["label"] = decryptedKey
                    case "range":
                        newWallet["range"] = decryptedKey
                    default:
                        break
                    }
                }
            }
        }
        
        func loopThroughOldWallets(oldWallets: [[String:Any]]) {
            for (i, oldWallet) in oldWallets.enumerated() {
                newWallet["id"] = UUID()
                loopThroughOldWalletKeyPairs(oldWallet: oldWallet)
                saveNewWallet(wallet: newWallet)
                if i + 1 == oldWallets.count {
                    convertOldDescriptors()
                }
            }
        }
        
        func convertOldHdWallets() {
            cd.retrieveEntity(entityName: .oldHdWallets) {
                let oldWallets = cd.entities
                if oldWallets.count > 0 {
                    loopThroughOldWallets(oldWallets: oldWallets)
                } else {
                    convertOldDescriptors()
                }
            }
        }
        
        func saveNewNode(newNode: [String:Any]) {
            cd.saveEntity(dict: newNode, entityName: .newNodes) {
                if !cd.boolToReturn {
                    completion(false)
                }
            }
        }
        
        func loopThroughKeyValuePairs(node: [String:Any]) {
            /// Gets the plain text and encrypted values and sets them to our new data structure.
            for (key, value) in node {
                switch key {
                case "isActive":
                    newNode["isActive"] = value
                    break
                default:
                    break
                }
                if key != "id" && key != "usingTor" && key != "usingSSH" && key != "isActive" && key != "isDefault" {
                    let decryptedKey = aesService.decryptOldKey(keyToDecrypt: value as! String)
                    if key == "label" {
                        newNode["label"] = decryptedKey
                    }
                    if let encryptedData = encrypt(decryptedKey.dataUsingUTF8StringEncoding) {
                        switch key {
                        case "authKey":
                            newNode["authKey"] = encryptedData
                        case "authPubKey":
                            newNode["authPubKey"] = encryptedData
                        case "onionAddress":
                            newNode["onionAddress"] = encryptedData
                        case "rpcpassword":
                            newNode["rpcpassword"] = encryptedData
                        case "rpcuser":
                            newNode["rpcuser"] = encryptedData
                        default:
                            break
                        }
                    } else {
                        completion(false)
                    }
                }
            }
        }
        
        func loopThroughNodes(nodes: [[String:Any]]) {
            for (i, node) in nodes.enumerated() {
                loopThroughKeyValuePairs(node: node)
                newNode["id"] = UUID()
                saveNewNode(newNode: newNode)
                if i + 1 == nodes.count {
                    convertOldHdWallets()
                }
            }
        }
        
        func convertNodes() {
            cd.retrieveEntity(entityName: .oldNodes) {
                let nodes = cd.entities
                if nodes.count > 0 {
                    loopThroughNodes(nodes: nodes)
                } else {
                    convertOldHdWallets()
                }
            }
        }
        
        if KeyChain.getData("privateKey") == nil {
            /// Sets a new encryption key.
            let pk = Crypto.privateKey()
            if KeyChain.set(pk, forKey: "privateKey") {
                /// Check if user already has an old style encryption key.
                if let _ = KeyChain.getData(KeychainKeys.aesPassword.rawValue) {
                    /// User has an old style key. We need to convert all existing encrypted data
                    /// to ChaChaPoly using our new privateKey.
                    convertNodes()
                    
                } else {
                    /// Do not need to do anything.
                    completion(true)
                }
            }
        } else {
            completion(true)
        }
        
    }
    
}

