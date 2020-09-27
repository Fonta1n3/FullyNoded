//
//  UTXOs.swift
//  FullyNoded
//
//  Created by Peter on 9/27/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

public struct UtxosStruct: CustomStringConvertible {
    
    let id: UUID
    let label: String
    let address: String
    let amount: Double
    let desc: String
    let solvable: Bool
    let txid: String
    let vout: Int64
    
    init(dictionary: [String: Any]) {
        id = dictionary["id"] as! UUID
        label = dictionary["label"] as? String ?? ""
        address = dictionary["address"] as? String ?? ""
        amount = dictionary["amount"] as? Double ?? 0.0
        desc = dictionary["desc"] as? String ?? ""
        solvable = dictionary["solvable"] as? Bool ?? false
        txid = dictionary["txid"] as? String ?? ""
        vout = dictionary["vout"] as? Int64 ?? 0
    }
    
    public var description: String {
        return ""
    }
    
}
