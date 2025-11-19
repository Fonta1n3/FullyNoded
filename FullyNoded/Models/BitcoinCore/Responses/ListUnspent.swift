//
//  UtxoResponse.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/9/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import Foundation

struct UTXO: Identifiable {
    let id = UUID()
    
    // All fields optional — safe for any Bitcoin Core version
    let address: String?
    let amount: Decimal          // Use Decimal? — never lose precision
    let confirmations: Int
    let desc: String?
    let label: String?
    let parentDescs: [String]
    let reused: Bool?
    let scriptPubKey: String
    let solvable: Bool
    let spendable: Bool
    let txid: String
    let vout: Int
    
    // Raw original dictionary (always preserved)
    let rawData: [String: Any]
    
    // Safe helpers
    var safeAmount: Decimal { amount }
    
    var btcAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 8
        formatter.minimumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount) BTC"
    }
    
    var outpoint: String {
        return "\(txid):\(vout)"
    }
    
    var isSpendable: Bool { spendable }
}

extension UTXO {
    init(from raw: [String: Any]) {
        self.rawData = raw
        
        // Safely extract everything — no crashes ever
        address = raw["address"] as? String
        confirmations = raw["confirmations"] as! Int
        desc = raw["desc"] as? String
        label = raw["label"] as? String
        parentDescs = raw["parent_descs"] as! [String]
        reused = raw["reused"] as? Bool
        scriptPubKey = raw["scriptPubKey"] as! String
        solvable = raw["solvable"] as! Bool
        spendable = raw["spendable"] as! Bool
        txid = raw["txid"] as! String
        vout = raw["vout"] as! Int
        let amountDouble = raw["amount"] as! Double
        amount = Decimal(amountDouble)
    }
}

// MARK: - Array Parser (One-Liner Magic)
extension Array where Element == UTXO {
    static func from(rawArray: [[String: Any]]) -> [UTXO] {
        return rawArray.map { UTXO(from: $0) }
    }
}
