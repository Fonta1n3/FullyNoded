//
//  AddressStruct.swift
//  FullyNoded
//
//  Created by Peter Denton on 12/6/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import Foundation

struct AddressStruct: CustomStringConvertible {
    let address: String
    let derivation: String
    var balance: Double
    var used: Bool
    
    init(dictionary: [String: Any]) {
        address = dictionary["address"] as! String
        derivation = dictionary["derivation"] as! String
        balance = dictionary["balance"] as! Double
        used = dictionary["used"] as! Bool
    }
    
    var description: String {
        return ""
    }
}
