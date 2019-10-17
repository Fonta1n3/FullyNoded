//
//  KillSwitch.swift
//  BitSense
//
//  Created by Peter on 25/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation
import KeychainSwift

class KillSwitch {
    
    let cd = CoreDataService()
    let ud = UserDefaults.standard
    
    func resetApp(vc: UIViewController) -> Bool {
        
        var boolToReturn = false
        let domain = Bundle.main.bundleIdentifier!
        ud.removePersistentDomain(forName: domain)
        ud.synchronize()
        let remainingDefaults = Array(ud.dictionaryRepresentation().keys).count
        print("remainingDefaults = \(remainingDefaults)")
        
        let descriptors = cd.retrieveEntity(entityName: ENTITY.descriptors)
        let nodes = cd.retrieveEntity(entityName: ENTITY.nodes)
        let hdwallets = cd.retrieveEntity(entityName: ENTITY.hdWallets)
        
        for d in descriptors {
            
            let str = DescriptorStruct(dictionary: d)
            let id = str.id
            let _ = cd.deleteEntity(viewController: vc, id: id, entityName: ENTITY.descriptors)
            
        }
        
        for n in nodes {
            
            let str = NodeStruct(dictionary: n)
            let id = str.id
            let _ = cd.deleteEntity(viewController: vc, id: id, entityName: ENTITY.nodes)
            
        }
        
        for h in hdwallets {
            
            let str = Wallet(dictionary: h)
            let id = str.id
            let _ = cd.deleteEntity(viewController: vc, id: id, entityName: ENTITY.hdWallets)
            
        }
        
        let descriptorCheck = cd.retrieveEntity(entityName: ENTITY.descriptors)
        let nodeCheck = cd.retrieveEntity(entityName: ENTITY.nodes)
        let hdwalletCheck = cd.retrieveEntity(entityName: ENTITY.hdWallets)
        
        if descriptorCheck.count == 0 && nodeCheck.count == 0 && hdwalletCheck.count == 0 {
            
            let keychain = KeychainSwift()
            
            if keychain.clear() {
                
                boolToReturn = true
                
            }
            
        }
        
        return boolToReturn
        
    }
    
}
