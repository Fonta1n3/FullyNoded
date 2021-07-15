//
//  TransactionStruct.swift
//  FullyNoded
//
//  Created by Peter on 1/6/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

public struct TransactionStruct: CustomStringConvertible, Codable {
    
    let id: UUID?
    let label: String
    let txid: String
    let fxRate: Double?
    let memo: String
    let date: Date?
    let fiatCurrency:String
    
    init(dictionary: [String: Any]) {
        id = dictionary["id"] as? UUID
        label = dictionary["label"] as? String ?? "no transaction label"
        fxRate = dictionary["originFxRate"] as? Double
        txid = dictionary["txid"] as? String ?? ""
        memo = dictionary["memo"] as? String ?? "no transaction memo"
        date = dictionary["date"] as? Date
        fiatCurrency = dictionary["fiatCurrency"] as? String ?? "USD"
    }
    
    public var description: String {
        return ""
    }
    
}
