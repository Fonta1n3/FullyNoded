//
//  WalletLock.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/21/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

/*
{
    "already_locked" = 0;
    walletname = "FullyNoded-yJyq5ibQwT.jmdat";
}
*/

public struct WalletLocked: CustomStringConvertible {
    let already_locked: Bool
    let walletname: String
    
    init(_ dictionary: [String: Any]) {
        already_locked = dictionary["already_locked"] as! Bool
        walletname = dictionary["walletname"] as! String
    }
    
    public var description: String {
        return ""
    }
}
