//
//  UtxoResponse.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/9/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import Foundation

/*
     "txid" : "hex",              (string) the transaction id
     "vout" : n,                  (numeric) the vout value
     "address" : "str",           (string, optional) the bitcoin address
     "label" : "str",             (string, optional) The associated label, or "" for the default label
     "scriptPubKey" : "str",      (string) the output script
     "amount" : n,                (numeric) the transaction output amount in BTC
     "confirmations" : n,         (numeric) The number of confirmations
     "ancestorcount" : n,         (numeric, optional) The number of in-mempool ancestor transactions, including this one (if transaction is in the mempool)
     "ancestorsize" : n,          (numeric, optional) The virtual transaction size of in-mempool ancestors, including this one (if transaction is in the mempool)
     "ancestorfees" : n,          (numeric, optional) The total fees of in-mempool ancestors (including this one) with fee deltas used for mining priority in sat (if transaction is in the mempool)
     "redeemScript" : "hex",      (string, optional) The redeem script if the output script is P2SH
     "witnessScript" : "str",     (string, optional) witness script if the output script is P2WSH or P2SH-P2WSH
     "spendable" : true|false,    (boolean) Whether we have the private keys to spend this output
     "solvable" : true|false,     (boolean) Whether we know how to spend this output, ignoring the lack of keys
     "reused" : true|false,       (boolean, optional) (only present if avoid_reuse is set) Whether this output is reused/dirty (sent to an address that was previously spent from)
     "desc" : "str",              (string, optional) (only when solvable) A descriptor for spending this output
     "parent_descs" : [           (json array) List of parent descriptors for the output script of this coin.
       "str",                     (string) The descriptor string.
       ...
     ],
     "safe" : true|false          (boolean) Whether this output is considered safe to spend. Unconfirmed transactions
                                  from outside keys and unconfirmed replacement transactions are considered unsafe
                                  and are not eligible for spending by fundrawtransaction and sendtoaddress.
 */

struct UTXO: Identifiable {
    let id = UUID()
    let address: String?
    let amount: Double
    let confirmations: Int
    let desc: String?
    let label: String?
    let parentDescs: [String]?
    let reused: Bool?
    let scriptPubKey: String?
    let solvable: Bool
    let spendable: Bool?
    let txid: String
    let vout: Int
    var walletId: UUID?
    
    
    let rawData: [String: Any]
    
    var outpoint: String {
        return "\(txid):\(vout)"
    }
    
}

extension UTXO {
    init(from raw: [String: Any]) {
        self.rawData = raw
        
        address = raw["address"] as? String
        confirmations = raw["confirmations"] as! Int
        desc = raw["desc"] as? String
        label = raw["label"] as? String
        parentDescs = raw["parent_descs"] as? [String]
        reused = raw["reused"] as? Bool
        scriptPubKey = raw["scriptPubKey"] as? String
        solvable = raw["solvable"] as! Bool
        spendable = raw["spendable"] as? Bool
        txid = raw["txid"] as! String
        vout = raw["vout"] as! Int
        amount = raw["amount"] as! Double
        walletId = raw["walletId"] as? UUID
        
    }
}

extension Array where Element == UTXO {
    static func from(rawArray: [[String: Any]]) -> [UTXO] {
        return rawArray.map { UTXO(from: $0) }
    }
}
