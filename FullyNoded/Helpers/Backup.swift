//
//  Backup.swift
//  FullyNoded
//
//  Created by Peter Denton on 8/5/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

class BackupiCloud {
        
    static func backup(completion: @escaping ((Bool)) -> Void) {
        var dataToBackup = [String:Any]()
        
        let entities:[ENTITY] = [
            .authKeys,
            .newNodes,
            .peers,
            .signers,
            .transactions,
            .utxos,
            .wallets
        ]
        
        for (x, entity) in entities.enumerated() {
            CoreDataService.retrieveEntity(entityName: entity) { dictArray in
                guard let dictArray = dictArray else { return }
                
                var newArray = [[String:Any]]()
                newArray = dictArray
                
                DispatchQueue.global(qos: .background).async {
                    for (i, dict) in dictArray.enumerated() {
                        for (key, value) in dict {
                            if key == "watching" {
                                if let array = value as? NSArray {
                                    var encryptedArray = [Data]()
                                    for (d, descriptor) in array.enumerated() {
                                        if let encrypted = Crypto.encryptForBackup((descriptor as! String).utf8) {
                                            encryptedArray.append(encrypted)
                                            if d + 1 == array.count {
                                                newArray[i]["\(key)"] = encryptedArray
                                            }
                                        }
                                    }
                                }
                            } else if let string = value as? String {
                                if !(entity == .newNodes && key == "label") {
                                    if let encrypted = Crypto.encryptForBackup(string.utf8) {
                                        newArray[i]["\(key)"] = encrypted
                                    }
                                }
                            } else if let data = value as? Data {
                                if let decrypted = Crypto.decrypt(data) {
                                    if let encrypted = Crypto.encryptForBackup(decrypted) {
                                        newArray[i]["\(key)"] = encrypted
                                    }
                                }
                            }
                            
                            if i + 1 == dictArray.count {
                                var newKey:ENTITY_BACKUP!
                                
                                switch entity {
                                case .authKeys:
                                    newKey = .authKeys
                                case .newNodes:
                                    newKey = .nodes
                                case .peers:
                                    newKey = .peers
                                case .signers:
                                    newKey = .signers
                                case .transactions:
                                    newKey = .transactions
                                case .utxos:
                                    newKey = .utxos
                                case .wallets:
                                    newKey = .wallets
                                }
                                
                                dataToBackup["\(newKey.rawValue)"] = newArray
                                
                                if x + 1 == entities.count {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        save(dataToBackup, completion: completion)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    static func save(_ dataToBackup: [String:Any], completion: @escaping ((Bool)) -> Void) {
        for (key, value) in dataToBackup {
            var savedAll = true
            if let dictArray = value as? [[String:Any]], let entity = ENTITY_BACKUP(rawValue: key) {
                for (i, dict) in dictArray.enumerated() {
                    CoreDataiCloud.deleteEntity(entity: entity) { deleted in
                        if deleted {
                            CoreDataiCloud.saveEntity(entity: entity, dict: dict) { saved in
                                if !saved {
                                    savedAll = false
                                }
                                if i + 1 == dictArray.count {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        completion((savedAll))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    static func destroy(completion: @escaping ((Bool)) -> Void) {
        let entities:[ENTITY_BACKUP] = [
            .authKeys,
            .nodes,
            .peers,
            .signers,
            .transactions,
            .utxos,
            .wallets
        ]
        
        var deletedAll = true
        
        for (i, entity) in entities.enumerated() {
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
