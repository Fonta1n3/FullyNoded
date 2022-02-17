//
//  Backup.swift
//  FullyNoded
//
//  Created by Peter Denton on 8/5/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

class BackupiCloud {
    
    static func encryptValuesForiCloud(_ encryptionKey: Data, _ existingLocalEntity: [String:Any], _ entity: ENTITY) -> [String:Any] {
        var item = existingLocalEntity
        item.removeValue(forKey: "watching")
        item.removeValue(forKey: "mixIndexes")
        
        for (key, value) in item {
            switch value {
            case let string as String:
                if !(entity == .newNodes && key == "label") {
                    if let encrypted = Crypto.encryptForBackup(encryptionKey, string.utf8) {
                        item["\(key)"] = encrypted
                    }
                }
                
            case let data as Data:
                if let decrypted = Crypto.decrypt(data) {
                    if let encrypted = Crypto.encryptForBackup(encryptionKey, decrypted) {
                        item["\(key)"] = encrypted
                    }
                }
            default:
                break
            }
        }
        
        return item
    }
        
    static func backup(encryptionKey: Data, completion: @escaping ((backedup: Bool, message: String?)) -> Void) {
        var saved = true
        
        let sha = Crypto.sha256hash(encryptionKey)
        
        if let existing = KeyChain.getData("iCloudSHA") {
            guard existing == Crypto.sha256hash(sha) else {
                completion((false, "Provided encryption key does not match last used encryption key."))
                return
            }
            
        } else {
            guard KeyChain.set(Crypto.sha256hash(sha), forKey: "iCloudSHA") else {
                completion((false, "Unable to save hash..."))
                return
            }
        }
        
        let entities:[ENTITY] = [
            .authKeys,
            .newNodes,
            .signers,
            .wallets,
            .jmWallets
        ]
        
        for (e, entity) in entities.enumerated() {
            var backupEntity:ENTITY_BACKUP!
            
            switch entity {
            case .authKeys:
                backupEntity = .authKeys
            case .newNodes:
                backupEntity = .nodes
            case .signers:
                backupEntity = .signers
            case .wallets:
                backupEntity = .wallets
            case .jmWallets:
                backupEntity = .jmWallets
            default:
                break
            }
            
            CoreDataService.retrieveEntity(entityName: entity) { localEntities in
                
                if let localEntities = localEntities, localEntities.count > 0 {
                    
                    func saveDict(_ dict: [String:Any], _ index: Int, _ name: ENTITY_BACKUP) {
                        CoreDataiCloud.saveEntity(entity: name, dict: dict) { success in
                            if !success {
                                saved = false
                            }

                            if e + 1 == entities.count && index + 1 == localEntities.count  {
                                completion((saved, nil))
                            }
                        }
                    }
                    
                    CoreDataiCloud.retrieveEntity(entity: backupEntity) { existingCloudEntities in
                        
                        for (i, existingLocalEntity) in localEntities.enumerated() {
                            
                            if let existingCloudEntities = existingCloudEntities, existingCloudEntities.count > 0 {
                                var exists = false
                                
                                for (x, existingCloudEntity) in existingCloudEntities.enumerated() {
                                    if let id = existingCloudEntity["id"] as? UUID, let idToBackup = existingLocalEntity["id"] as? UUID, id == idToBackup {
                                        exists = true
                                    }
                                    
                                    if x + 1 == existingCloudEntities.count && !exists {
                                        let encryptedDict = encryptValuesForiCloud(encryptionKey, existingLocalEntity, entity)
                                        saveDict(encryptedDict, i, backupEntity)
                                    } else if x + 1 == existingCloudEntities.count && e + 1 == entities.count && i + 1 == localEntities.count {
                                        completion((saved, nil))
                                    }
                                }
                                
                            } else {
                                //nothing on icloud back it all up
                                let encryptedDict = encryptValuesForiCloud(encryptionKey, existingLocalEntity, entity)
                                saveDict(encryptedDict, i, backupEntity)
                            }
                        }
                    }
                } else {
                    completion((true, "No data to backup."))
                }
            }
        }
    }
    
    static func convertDataToRecoverIntoArrays(_ dataToRecover: [String:Any]) -> [[[String:Any]]]? {
        guard !dataToRecover.isEmpty else { return nil }
        
        var authKeys = [[String:Any]]()
        var nodes = [[String:Any]]()
        var signers = [[String:Any]]()
        var wallets = [[String:Any]]()
        var jmWallets = [[String:Any]]()
        
        for (key, value) in dataToRecover {
            guard let entity = ENTITY(rawValue: key) else { print("not an entity"); return nil }
            
            guard let dictArray = value as? [[String:Any]] else { print("not an array of dicts"); return nil }
            
            switch entity {
            case .authKeys:
                authKeys = dictArray
            case .newNodes:
                nodes = dictArray
            case .signers:
                signers = dictArray
            case .wallets:
                wallets = dictArray
            case .jmWallets:
                jmWallets = dictArray
            default:
                break
            }
        }
        
        return [authKeys, nodes, signers, wallets, jmWallets]
    }
    
    static func saveEntityLocal(_ name: ENTITY, _ entity: [String:Any], completion: @escaping ((success:Bool, didSaveSomething: Bool)) -> Void) {
        var saved = true
        var didSaveSomething = false
        
        func saveDict(_ dict: [String:Any]) {
            CoreDataService.saveEntity(dict: dict, entityName: name) { success in
                if !success {
                    saved = false
                } else {
                    didSaveSomething = true
                }
                
                completion((saved, didSaveSomething))
            }
        }
        
        CoreDataService.retrieveEntity(entityName: name) { existingEntities in
            if let existingEntities = existingEntities, existingEntities.count > 0 {
                var exists = false
                for (x, existingEntity) in existingEntities.enumerated() {
                    if let id = existingEntity["id"] as? UUID, let idToSave = entity["id"] as? UUID , id == idToSave {
                        exists = true
                    }
                    
                    if x + 1 == existingEntities.count {
                        if !exists {
                            saveDict(entity)
                        } else {
                            completion((true, false))
                        }
                    }
                }
            } else {
                saveDict(entity)
            }
        }
    }
        
    static func saveRecoveredDataLocally(_ dataToRecover: [String:Any], completion: @escaping ((recovered: Bool, message: String?)) -> Void) {
        if !dataToRecover.isEmpty {
            if let entitiesToRecover = convertDataToRecoverIntoArrays(dataToRecover) {
                var backedUp = true
                var somethingWasSaved = false
                
                for (i, entities) in entitiesToRecover.enumerated() {
                    
                    func finished() {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            var mess = "Data was recovered."
                            if !somethingWasSaved {
                                mess = "No data to recover."
                            }
                            completion((backedUp, mess))
                        }
                    }
                    
                    if !entities.isEmpty {
                        switch i {
                        case 0:
                            for entity in entities {
                                saveEntityLocal(.authKeys, entity) { (success, didSave) in
                                    if !success {
                                        backedUp = false
                                    }
                                    if didSave {
                                        somethingWasSaved = true
                                    }
                                }
                            }
                            
                        case 1:
                            for entity in entities {
                                saveEntityLocal(.newNodes, entity) { (success, didSave) in
                                    if !success {
                                        backedUp = false
                                    }
                                    if didSave {
                                        somethingWasSaved = true
                                    }
                                }
                            }
                        case 2:
                            for entity in entities {
                                saveEntityLocal(.signers, entity) { (success, didSave) in
                                    if !success {
                                        backedUp = false
                                    }
                                    if didSave {
                                        somethingWasSaved = true
                                    }
                                }
                            }
                        case 3:
                            for entity in entities {
                                saveEntityLocal(.wallets, entity) { (success, didSave) in
                                    if !success {
                                        backedUp = false
                                    }
                                    
                                    if didSave {
                                        somethingWasSaved = true
                                    }
                                }
                            }
                        case 4:
                            if entities.count > 0 {
                                for (x, entity) in entities.enumerated() {
                                    saveEntityLocal(.jmWallets, entity) { (success, didSave) in
                                        if !success {
                                            backedUp = false
                                        }
                                        
                                        if didSave {
                                            somethingWasSaved = true
                                        }
                                        
                                        if x + 1 == entities.count {
                                            finished()
                                        }
                                    }
                                }
                            } else {
                                finished()
                            }
                        default:
                            break
                        }
                    }
                }
            } else {
                completion((false, "Error converting recovery data into arrays."))
            }
        } else {
            completion((false, "No data exists in iCloud."))
        }
    }
    
    static func destroy(completion: @escaping ((Bool)) -> Void) {
        print("destroy")
        let entities:[ENTITY_BACKUP] = [
            .authKeys,
            .nodes,
            .signers,
            .wallets,
            .jmWallets
        ]
        
        var deletedAll = true
        
        for (i, entity) in entities.enumerated() {
            CoreDataiCloud.retrieveEntity(entity: entity) { existingEntity in
                guard let existingEntity = existingEntity, !existingEntity.isEmpty else {
                    print("no existing entity for: \(entity.rawValue)")
                    if i + 1 == entities.count {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            completion((deletedAll))
                        }
                    }
                    return
                }
                
                CoreDataiCloud.deleteEntity(entity: entity) { deleted in
                    if !deleted {
                        deletedAll = false
                    }
                    
                    if i + 1 == entities.count {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            completion((deletedAll))
                        }
                    }
                }
            }
        }
    }
    
    static func recover(passwordHash: Data, completion: @escaping ((recovered: Bool, message: String?)) -> Void) {
        let sha = Crypto.sha256hash(passwordHash)
        
        if let existing = KeyChain.getData("iCloudSHA") {
            guard existing == Crypto.sha256hash(sha) else {
                completion((false, "Provided encryption key does not match last used encryption key."))
                return
            }
            
        } else {
            guard KeyChain.set(Crypto.sha256hash(sha), forKey: "iCloudSHA") else {
                completion((false, "Unable to save hash..."))
                return
            }
        }
        
        var dataToRecover = [String:Any]()
        
        let entities:[ENTITY_BACKUP] = [
            .authKeys,
            .nodes,
            .signers,
            .wallets,
            .jmWallets
        ]
        
        for (x, entity) in entities.enumerated() {
            CoreDataiCloud.retrieveEntity(entity: entity) { dictArray in
                if let dictArray = dictArray, dictArray.count > 0 {
                    var newArray = [[String:Any]]()
                    
                    for (i, dict) in dictArray.enumerated() {
                        var item = dict
                        item.removeValue(forKey: "watching")
                        item.removeValue(forKey: "mixIndexes")
                        
                            for (key, value) in item {
                                if let data = value as? Data {
                                    
                                    switch key {
                                    case "publicKey",
                                        "label",
                                        "name",
                                        "changeDescriptor",
                                        "receiveDescriptor",
                                        "type",
                                        "fnWallet":
                                        
                                        if !(entity == .nodes && key == "label") {
                                            if let decrypted = Crypto.decryptForBackup(passwordHash, data), let string = decrypted.utf8String {
                                                item["\(key)"] = string
                                            }
                                        }
                                        
                                    case "privateKey",
                                        "cert",
                                        "macaroon",
                                        "onionAddress",
                                        "rpcpassword",
                                        "rpcuser",
                                        "passphrase",
                                        "words",
                                        "rootTpub",
                                        "rootXpub",
                                        "bip84tpub",
                                        "bip84xpub",
                                        "bip48tpub",
                                        "bip48xpub",
                                        "xfp":
                                        
                                        if let decrypted = Crypto.decryptForBackup(passwordHash, data) {
                                            if let encrypted = Crypto.encrypt(decrypted) {
                                                item["\(key)"] = encrypted
                                            }
                                        }
                                        
                                    default:
                                        break
                                    }
                                }
                            }
                        
                            newArray.append(item)
                            
                            if i + 1 == dictArray.count {
                                var newKey:ENTITY!
                                
                                switch entity {
                                case .authKeys:
                                    newKey = .authKeys
                                case .nodes:
                                    newKey = .newNodes
                                case .signers:
                                    newKey = .signers
                                case .wallets:
                                    newKey = .wallets
                                case .jmWallets:
                                    newKey = .jmWallets
                                }
                                
                                dataToRecover["\(newKey.rawValue)"] = newArray
                                
                                if x + 1 == entities.count {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                        saveRecoveredDataLocally(dataToRecover, completion: completion)
                                    }
                                }
                            }
                    }
                } else {
                    if x + 1 == entities.count {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            saveRecoveredDataLocally(dataToRecover, completion: completion)
                        }
                    }
                }
            }
        }
    }
}
