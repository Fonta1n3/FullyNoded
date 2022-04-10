//
//  JMUtxo.swift
//  FullyNoded
//
//  Created by Peter Denton on 2/7/22.
//  Copyright © 2022 Fontaine. All rights reserved.
//

import Foundation
/*
 address = v;
 confirmations = 5856;
 external = 0;
 frozen = 1;
 label = "";
 locktime = "2022-02-01 00:00:00";
 mixdepth = 0;
 path = "m/84'/0'/0'/2/25:1643673600";
 tries = 0;
 "tries_remaining" = 3;
 utxo = "h:0";
 value = j
 */

struct JMUtxo: CustomStringConvertible {
    
    let utxoString: String
    let frozen: Bool
    let locktime: Date?
    
    init(_ dict: [String:Any]) {
        utxoString = dict["utxo"] as! String
        frozen = dict["frozen"] as! Bool
        let rawLocktime = dict["locktime"] as? String
        
        let dateFormatterGet = DateFormatter()
        dateFormatterGet.dateFormat = "yyyy-MM-dd HH:mm:ss"

        if let rawLocktime = rawLocktime, let date = dateFormatterGet.date(from: rawLocktime) {
            locktime = date
        } else {
            locktime = nil
        }
    }
    
    public var description: String {
        return ""
    }
}
