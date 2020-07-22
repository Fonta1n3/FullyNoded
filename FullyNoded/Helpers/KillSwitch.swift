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
        let domain = Bundle.main.bundleIdentifier!
        ud.removePersistentDomain(forName: domain)
        ud.synchronize()
        let entities = [ENTITY.newNodes, ENTITY.newHdWallets, ENTITY.newDescriptors, ENTITY.signers, ENTITY.wallets, ENTITY.authKeys]
        for entity in entities {
            CoreDataService.deleteAllData(entity: entity) { _ in }
        }
        KeyChain.removeAll()
        return true
    }
}
