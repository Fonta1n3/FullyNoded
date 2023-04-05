//
//  UTXOs.swift
//  FullyNoded
//
//  Created by Peter on 9/27/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation
import UIKit

public struct Utxo: CustomStringConvertible {
    
    let id: UUID?
    var label: String?
    let address: String?
    var amount: Double?
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
    var commitment: String?
    let dict: [String:Any]
    var isJoinMarket: Bool
    let frozen: Bool?
    let mixdepth: Int?
    let path: String?
    let value: Int?
    let tries_remaining: Int?
    let utxo: String?
    
    /*
     JM utxo
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
     */
    
    init(_ dictionary: [String: Any]) {
        id = dictionary["id"] as? UUID
        label = dictionary["label"] as? String
        address = dictionary["address"] as? String
        amount = dictionary["amount"] as? Double
        desc = dictionary["desc"] as? String
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
        commitment = dictionary["commitment"] as? String
        frozen = dictionary["frozen"] as? Bool
        mixdepth = dictionary["mixdepth"] as? Int
        path = dictionary["path"] as? String
        value = dictionary["value"] as? Int
        isJoinMarket = dictionary["isJoinMarket"] as? Bool ?? (mixdepth != nil)
        solvable = dictionary["solvable"] as? Bool ?? (mixdepth != nil)
        if mixdepth != nil {
            amount = (dictionary["value"] as! Int).satsToBtcDouble
        }
        tries_remaining = dictionary["tries_remaining"] as? Int
        utxo = dictionary["utxo"] as? String
        dict = dictionary
    }
    
    public var description: String {
        return ""
    }
    
}
