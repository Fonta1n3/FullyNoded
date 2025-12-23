//
//  AccountMap.swift
//  BitSense
//
//  Created by Peter on 16/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation
//import UIKit
//import LibWally

class CreateAccountMap {
    
    class func create(wallet: Wallet) -> String? {
        guard let primDesc = processedDesc(wallet.receiveDescriptor) else { return nil }
        
        let dict = [
            "descriptor":"\(primDesc)",
            "blockheight":Int64(wallet.blockheight),
            "label":wallet.label
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
