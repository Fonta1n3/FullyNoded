//
//  AccountMap.swift
//  BitSense
//
//  Created by Peter on 16/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation
import UIKit

class AccountMap {
    
    class func create(wallet: Wallet) -> String? {
        let primDesc = processedDesc(wallet.receiveDescriptor)
        var watching = [String]()
        
        if wallet.watching != nil {
            for desc in wallet.watching! {
                watching.append(processedDesc(desc))
            }
        }
        
        let dict = ["descriptor":"\(primDesc)", "blockheight":Int(wallet.blockheight),"label":wallet.label,"watching":watching] as [String : Any]
        
        return dict.json()
    }
    
    class func processedDesc(_ desc: String) -> String {
        let processedDesc = desc.replacingOccurrences(of: "'", with: "h")
        let arr = processedDesc.split(separator: "#")
        
        return "\(arr[0])"
    }
    
}
