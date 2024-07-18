//
//  AccountMap.swift
//  BitSense
//
//  Created by Peter on 16/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation
import UIKit
import LibWally

class CreateAccountMap {
    
    class func create(wallet: Wallet) -> String? {
        guard var primDesc = processedDesc(wallet.receiveDescriptor) else { return nil }
        var watching = [String]()
        
        if wallet.watching != nil {
            for desc in wallet.watching! {
                guard let processedWatchingDesc = processedDesc(desc) else { return nil }
                watching.append(processedWatchingDesc)
            }
        }
        
        // Don't show xprvs in backup QR incase user imported an xprv
        let ds = Descriptor(primDesc)
        
        if ds.isHot && !ds.isMulti {
//            if let key = try? HDKey(base58: ds.accountXprv) {
//                primDesc = primDesc.replacingOccurrences(of: ds.accountXprv, with: key.xpub)
//                
//                for (i, _) in watching.enumerated() {
//                    watching[i] = watching[i].replacingOccurrences(of: ds.accountXprv, with: key.xpub)
//                }
//            }
        } else if ds.isHot {
            for key in ds.multiSigKeys {
//                if key.hasPrefix("xprv") || key.hasPrefix("tprv") {
//                    if let hdkey = try? HDKey(base58: key) {
//                        primDesc = primDesc.replacingOccurrences(of: key, with: hdkey.xpub)
//                        
//                        for (i, _) in watching.enumerated() {
//                            watching[i] = watching[i].replacingOccurrences(of: key, with: hdkey.xpub)
//                        }
//                    }
//                }
            }
        }
        
        let dict = [
            "descriptor":"\(primDesc)",
            "blockheight":Int64(wallet.blockheight),
            "label":wallet.label,
            "watching":watching
        ] as [String : Any]
        
        return dict.json()
    }
    
    class func processedDesc(_ desc: String) -> String? {
        guard desc != "" else {
            return nil
        }
        let processedDesc = desc.replacingOccurrences(of: "'", with: "h")
        let arr = processedDesc.split(separator: "#")
        
        guard arr.count > 0 else {
            return nil
        }
        return "\(arr[0])"
    }
    
}
