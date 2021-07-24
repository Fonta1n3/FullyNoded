//
//  UTXOs.swift
//  FullyNoded
//
//  Created by Peter on 9/27/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation
import UIKit

public struct UtxosStruct: CustomStringConvertible {
    
    let id: UUID?
    var label: String?
    let address: String?
    let amount: Double?
    let desc: String?
    let solvable: Bool?
    let txid: String
    let vout: Int64
    let walletId: UUID?
    let confs: Int64?
    let safe: Bool?
    let spendable: Bool?
    var isSelected: Bool
    let reused: Bool?
    let capGain:String?
    let originValue:String?
    let date: Date?
    let txUUID: UUID?
    let amountFiat: String?
    let amountSats: String?
    let lifehash: UIImage?
    
    init(dictionary: [String: Any]) {
        id = dictionary["id"] as? UUID
        label = dictionary["label"] as? String
        address = dictionary["address"] as? String
        amount = dictionary["amount"] as? Double
        desc = dictionary["desc"] as? String
        solvable = dictionary["solvable"] as? Bool
        txid = dictionary["txid"] as? String ?? ""
        vout = dictionary["vout"] as? Int64 ?? 0
        walletId = dictionary["walletId"] as? UUID
        confs = dictionary["confirmations"] as? Int64
        spendable = dictionary["spendable"] as? Bool
        safe = dictionary["safe"] as? Bool
        isSelected = dictionary["isSelected"] as? Bool ?? false
        reused = dictionary["reused"] as? Bool
        capGain = dictionary["capGain"] as? String
        originValue = dictionary["originValue"] as? String
        date = dictionary["date"] as? Date
        txUUID = dictionary["txUUID"] as? UUID
        amountFiat = dictionary["amountFiat"] as? String
        amountSats = dictionary["amountSats"] as? String
        lifehash = dictionary["lifehash"] as? UIImage
    }
    
    public var description: String {
        return ""
    }
    
}
