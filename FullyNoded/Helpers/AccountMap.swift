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
        var processedDesc = wallet.receiveDescriptor.replacingOccurrences(of: "'", with: "h")
        let arr = processedDesc.split(separator: "#")
        processedDesc = "\(arr[0])"
        let dict = ["descriptor":"\(processedDesc)", "blockheight":Int(wallet.blockheight),"label":wallet.label] as [String : Any]
        return dict.json()
    }
    
}
