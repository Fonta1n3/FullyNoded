//
//  UsedAddresses.swift
//  FullyNoded
//
//  Created by Peter Denton on 12/30/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import Foundation

public struct UsedAddress: CustomStringConvertible {
    
    let address: String
    let id: UUID
    
    init(dictionary: [String: Any]) {
        address = dictionary["address"] as! String
        id = dictionary["id"] as! UUID
    }
    
    public var description: String {
        return "Addresses that have been used nodelessly."
    }
}
