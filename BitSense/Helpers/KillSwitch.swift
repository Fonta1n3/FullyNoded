//
//  KillSwitch.swift
//  BitSense
//
//  Created by Peter on 25/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation
import UIKit

class KillSwitch {
    
    let cd = CoreDataService()
    let ud = UserDefaults.standard
    
    func resetApp(vc: UIViewController) -> Bool {
        
        var boolToReturn = false
        let domain = Bundle.main.bundleIdentifier!
        ud.removePersistentDomain(forName: domain)
        ud.synchronize()
        
        cd.retrieveEntity(entityName: .newDescriptors) {
            
            if !self.cd.errorBool {
                
                let descriptors = self.cd.entities
                for d in descriptors {
                    
                    let str = DescriptorStruct(dictionary: d)
                    let id = str.id
                    
                    self.cd.deleteNode(id: id!, entityName: .newDescriptors) { success in
                        
                        if success {
                            
                            boolToReturn = true
                            
                        }
                        
                    }
                    
                }
                
            } else {
                
                displayAlert(viewController: vc, isError: true, message: "error getting core data")
            }
            
        }
        
        cd.retrieveEntity(entityName: .newNodes) { [unowned ks = self] in
            if !ks.cd.errorBool {
                let nodes = ks.cd.entities
                for n in nodes {
                    let str = NodeStruct(dictionary: n)
                    if let id = str.id {
                        ks.cd.deleteNode(id: id, entityName: .newNodes) { success in
                            boolToReturn = success
                        }
                    }
                }
            } else {
                displayAlert(viewController: vc, isError: true, message: "error getting core data")
            }
        }
        
        cd.retrieveEntity(entityName: .newHdWallets) { [unowned ks = self] in
            
            if !ks.cd.errorBool {
                
                let hdwallets = ks.cd.entities
                for h in hdwallets {
                    
                    let str = Wallet(dictionary: h)
                    if let id = str.id {
                        
                        ks.cd.deleteNode(id: id, entityName: .newHdWallets) { [unowned ks = self] success in
                            
                            if !ks.cd.errorBool {
                                
                                let success = ks.cd.boolToReturn
                                
                                if success {
                                    
                                    boolToReturn = true
                                    
                                }
                                
                            }
                            
                        }
                        
                    }
                    
                }
                
            } else {
                
                displayAlert(viewController: vc, isError: true, message: "error getting core data")
                
            }
            
        }
        
        let _ = KeyChain.remove(key: "UnlockPassword")
        
        let _ = KeyChain.remove(key: KeychainKeys.privateKey.rawValue)
        
        if KeyChain.remove(key: KeychainKeys.aesPassword.rawValue) {
            
            boolToReturn = true
            
        }
        
        return boolToReturn
        
    }
    
}
