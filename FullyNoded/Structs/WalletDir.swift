//
//  WalletDir.swift
//  FullyNoded
//
//  Created by Peter Denton on 9/26/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

public struct WalletDir: CustomStringConvertible {
    
    var wallets:[String]
    
    init(_ dictArray: [String: Any]) {
        var walletsToReturn:[String] = []
        
        let walletArray = dictArray["wallets"] as? [[String:Any]] ?? [[:]]
        
        for dict in walletArray {
            let name = dict["name"] as? String ?? ""
            walletsToReturn.append(name)
        }
        
        wallets = walletsToReturn
    }
    
    public var description: String {
        return ""
    }
}
