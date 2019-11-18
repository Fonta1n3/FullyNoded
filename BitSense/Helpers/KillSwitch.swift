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
        
        cd.retrieveEntity(entityName: .descriptors) {
            
            if !self.cd.errorBool {
                
                let descriptors = self.cd.entities
                for d in descriptors {
                    
                    let str = DescriptorStruct(dictionary: d)
                    let id = str.id
                    
                    self.cd.deleteEntity(id: id, entityName: .descriptors) {
                        
                        if !self.cd.errorBool {
                            
                            let success = self.cd.boolToReturn
                            
                            if success {
                                
                                boolToReturn = true
                                
                            }
                            
                        }
                        
                    }
                    
                }
                
            } else {
                
                displayAlert(viewController: vc, isError: true, message: "error getting core data")
            }
            
        }
        
        cd.retrieveEntity(entityName: .nodes) {
            
            if !self.cd.errorBool {
                
                let nodes = self.cd.entities
                for n in nodes {
                    
                    let str = NodeStruct(dictionary: n)
                    let id = str.id
                    
                    self.cd.deleteEntity(id: id, entityName: .nodes) {
                        
                        if !self.cd.errorBool {
                            
                            let success = self.cd.boolToReturn
                            
                            if success {
                                
                                boolToReturn = true
                                
                            }
                            
                        }
                        
                    }
                    
                }
                
            } else {
                
                displayAlert(viewController: vc, isError: true, message: "error getting core data")
            }
            
        }
        
        cd.retrieveEntity(entityName: .hdWallets) {
            
            if !self.cd.errorBool {
                
                let hdwallets = self.cd.entities
                for h in hdwallets {
                    
                    let str = Wallet(dictionary: h)
                    let id = str.id
                    
                    self.cd.deleteEntity(id: id, entityName: .hdWallets) {
                        
                        if !self.cd.errorBool {
                            
                            let success = self.cd.boolToReturn
                            
                            if success {
                                
                                boolToReturn = true
                                
                            }
                            
                        }
                        
                    }
                    
                }
                
            } else {
                
                displayAlert(viewController: vc, isError: true, message: "error getting core data")
                
            }
            
        }
        
        let keychain = KeychainSwift()
        
        if keychain.clear() {
            
            boolToReturn = true
            
        }
        
        return boolToReturn
        
    }
    
}
