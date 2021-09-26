//
//  WalletDir.swift
//  FullyNoded
//
//  Created by Peter Denton on 9/26/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

public struct WalletDir: CustomStringConvertible {
    
    var wallets:[String] = []
    
    init(_ dictArray: [[String: Any]]) {
        for dict in dictArray {
            let name = dict["name"] as? String ?? ""
            wallets.append(name)
        }
    }
    
    public var description: String {
        return ""
    }
}
