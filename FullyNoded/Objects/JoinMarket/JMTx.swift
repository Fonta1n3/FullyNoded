//
//  JMTx.swift
//  FullyNoded
//
//  Created by Peter Denton on 2/16/22.
//  Copyright © 2022 Fontaine. All rights reserved.
//

import Foundation

/*
 ["txinfo": {
     hex = xxx;
     inputs =     (
                 {
             nSequence = c;
             outpoint = "c:0";
             scriptSig = "";
             witness = h;
         }
     );
     nLockTime = j;
     nVersion = 2;
     outputs =     (
                 {
             address = j;
             scriptPubKey = j;
             "value_sats" = h;
         },
                 {
             address = h;
             scriptPubKey = jh;
             "value_sats" = j;
         }
     );
     txid = g;
 }]
 */

struct JMTx: CustomStringConvertible {
    
    let hex: String?
    let txid: String?
    
    init(_ dict: [String:Any]) {
        if let txinfo = dict["txinfo"] as? [String:Any] {
            hex = txinfo["hex"] as? String
            txid = txinfo["txid"] as? String
        } else {
            hex = nil
            txid = nil
        }
        
    }
    
    public var description: String {
        return ""
    }
}
