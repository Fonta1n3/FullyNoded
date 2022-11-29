//
//  JMUtxo.swift
//  FullyNoded
//
//  Created by Peter Denton on 2/7/22.
//  Copyright © 2022 Fontaine. All rights reserved.
//

import Foundation
/*
 utxos =     (
             {
         address = tb1q2njwafd6h6cs0pd5qjj2jwg0gvcxvqcslqx636;
         confirmations = 6;
         external = 0;
         frozen = 0;
         label = "";
         mixdepth = 0;
         path = "m/84'/1'/0'/0/0";
         tries = 0;
         "tries_remaining" = 3;
         utxo = "a65a026014c62ee4656ba189b001d22839ea8cd502bc511053db97811bd2c8c4:0";
         value = 999890;
     }
 )
 */

struct JMUtxo: CustomStringConvertible {
    
    let utxoString: String
    let frozen: Bool
    let locktime: Date?
//    let address: String
//    let label: String
//    let mixdepth: Int
//    let path: String
//    let tries: Int
//    let tries_remaining: Int
//    let utxo: String
//    let value: Int
    
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
