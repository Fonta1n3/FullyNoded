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
        
        var dataArray = [[String:Any]]()
        
        let entities:[ENTITY] = [
            .authKeys,
            .newNodes,
            .peers,
            .signers,
            .transactions,
            .utxos,
            .wallets
        ]
        
        for entity in entities {
            CoreDataService.retrieveEntity(entityName: entity) { data in
                guard let data = data else { return }
                
                print("\(entity.rawValue): \(data)")
                
//                switch entity {
//                case .authKeys:
//
//
//                }
                                
                //dataArray.append(["\(entity.rawValue)": data])
                //CoreDataiCloud.saveEntity(dict: <#T##[String : Any]#>, completion: <#T##((success: Bool, errorDescription: String?)) -> Void#>)
            }
        }
    }
    
    
}
