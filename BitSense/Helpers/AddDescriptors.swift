//
//  AddDescriptors.swift
//  BitSense
//
//  Created by Peter on 22/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class AddDescriptors {
    
    func addDescriptorsToCoreData() {
        
        let ud = UserDefaults.standard
        
        if ud.object(forKey: "hasAddedDescriptors") == nil {
            
            let cd = CoreDataService()
            let hdWallets = cd.retrieveEntity(entityName: ENTITY.hdWallets)
            var successes = [Bool]()
            
            for walletDict in hdWallets {
                
                let wallet = Wallet(dictionary: walletDict)
                let descriptor = wallet.descriptor
                let label = wallet.label
                let id = wallet.id
                let nodeID = wallet.nodeID
                let vc = MainMenuViewController()
                
                let dict = ["descriptor":descriptor,
                            "label":label,
                            "id":id,
                            "nodeID":nodeID]
                
                let success = cd.saveEntity(vc: vc,
                              dict: dict,
                              entityName: ENTITY.descriptors)
                
                successes.append(success)
                
            }
            
            var allSaved = true
            
            for b in successes {
                
                if !b {
                    
                    allSaved = false
                    
                }
                
            }
            
            if allSaved {
                
                ud.set(true, forKey: "hasAddedDescriptors")
                
            }
            
        }
        
    }
    
}
