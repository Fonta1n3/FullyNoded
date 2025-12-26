//
//  UTXOs.swift
//  FullyNoded
//
//  Created by Peter on 9/27/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

//import Foundation
//import UIKit

//public struct Utxo_: CustomStringConvertible {
//    
//    let id: UUID?
//    var label: String?
//    let address: String?
//    var amount: Double?
//    let desc: String?
//    let solvable: Bool?
//    let txid: String
//    let vout: Int64
//    let walletId: UUID?
//    let confs: Int64?
//    let safe: Bool?
//    let spendable: Bool?
//    let reused: Bool?
//    let originValue:String?
//    let date: Date?
//    let txUUID: UUID?
//    let amountFiat: String?
//    let amountSats: String?
//    let dict: [String:Any]
//    let utxo: String?
//    
//    init(_ dictionary: [String: Any]) {
//        id = dictionary["id"] as? UUID
//        label = dictionary["label"] as? String
//        address = dictionary["address"] as? String
//        amount = dictionary["amount"] as? Double
//        desc = dictionary["desc"] as? String
//        txid = dictionary["txid"] as? String ?? ""
//        vout = dictionary["vout"] as? Int64 ?? 0
//        walletId = dictionary["walletId"] as? UUID
//        confs = dictionary["confirmations"] as? Int64
//        spendable = dictionary["spendable"] as? Bool
//        safe = dictionary["safe"] as? Bool
//        reused = dictionary["reused"] as? Bool
//        originValue = dictionary["originValue"] as? String
//        date = dictionary["date"] as? Date
//        txUUID = dictionary["txUUID"] as? UUID
//        amountFiat = dictionary["amountFiat"] as? String
//        amountSats = dictionary["amountSats"] as? String
//        solvable = dictionary["solvable"] as? Bool
//        utxo = dictionary["utxo"] as? String
//        dict = dictionary
//    }
//    
//    public var description: String {
//        return "Utxo Info"
//    }
//    
//}
