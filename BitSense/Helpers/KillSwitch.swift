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
    
    let ud = UserDefaults.standard
    
    func resetApp(vc: UIViewController) -> Bool {
        
        var boolToReturn = false
        let domain = Bundle.main.bundleIdentifier!
        ud.removePersistentDomain(forName: domain)
        ud.synchronize()
        
        CoreDataService.retrieveEntity(entityName: .newDescriptors) { descriptors in
            if descriptors != nil {
                for d in descriptors! {
                    let str = DescriptorStruct(dictionary: d)
                    let id = str.id
                    CoreDataService.deleteEntity(id: id!, entityName: .newDescriptors) { success in
                        if success {
                            boolToReturn = true
                        }
                    }
                }
            } else {
                displayAlert(viewController: vc, isError: true, message: "error getting core data")
            }
        }
        
        CoreDataService.retrieveEntity(entityName: .newNodes) { nodes in
            if nodes != nil {
                for n in nodes! {
                    let str = NodeStruct(dictionary: n)
                    if let id = str.id {
                        CoreDataService.deleteEntity(id: id, entityName: .newNodes) { success in
                            boolToReturn = success
                        }
                    }
                }
            } else {
                displayAlert(viewController: vc, isError: true, message: "error getting core data")
            }
        }
        
        CoreDataService.retrieveEntity(entityName: .newHdWallets) { hdwallets in
            if hdwallets != nil {
                for h in hdwallets! {
                    let str = Wallet(dictionary: h)
                    if let id = str.id {
                        CoreDataService.deleteEntity(id: id, entityName: .newHdWallets) { success in
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
        let _ = KeyChain.remove(key: "UnlockPassword")
        let _ = KeyChain.remove(key: KeychainKeys.privateKey.rawValue)
        if KeyChain.remove(key: KeychainKeys.aesPassword.rawValue) {
            boolToReturn = true
        }
        return boolToReturn
    }
    
}
