//
//  WalletInfo.swift
//  FullyNoded
//
//  Created by Peter Denton on 7/26/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

public struct WalletInfo: CustomStringConvertible {
    
    let balance: Double?
    let descriptors: Int?
    let private_keys_enabled: Bool?
    let scanning: Bool
    let locked: Bool
    let walletname: String
    let progress: Double?
    
    init(_ dictionary: [String: Any]) {
        descriptors = RPCValue.int(dictionary["descriptors"])
        private_keys_enabled = RPCValue.bool(dictionary["private_keys_enabled"])
        scanning = (dictionary["scanning"] as? [String:Any] != nil)
        balance = RPCValue.double(dictionary["balance"])
        progress = RPCValue.double((dictionary["scanning"] as? [String:Any])?["progress"])
        walletname = dictionary["walletname"] as? String ?? ""
        
        if let unlockedUntil = RPCValue.int(dictionary["unlocked_until"]) {
            locked = !(unlockedUntil > 0)
        } else {
            locked = false
        }
    }
    
    public var description: String {
        return ""
    }
    
    /*
     {
         "avoid_reuse" = 0;
         balance = "0.00094503";
         descriptors = 0;
         format = bdb;
         hdseedid = ed16644481b1c04e0dd57bc59cfce03af374acd9;
         "immature_balance" = 0;
         keypoololdest = 1619160771;
         keypoolsize = 1000;
         "keypoolsize_hd_internal" = 999;
         paytxfee = 0;
         "private_keys_enabled" = 1;
         scanning = 0;
     scanning =         {
         duration = 17;
         progress = "0.1189073480362548";
     }
         txcount = 11;
         "unconfirmed_balance" = 0;
         "unlocked_until" = 0;
         walletname = default;
         walletversion = 169900;
     }
     */
    
}
