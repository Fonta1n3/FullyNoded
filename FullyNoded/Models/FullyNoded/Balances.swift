//
//  Balances.swift
//  BitSense
//
//  Created by Peter on 27/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

public struct Balances: CustomStringConvertible {
    
    let onchainBalance:String
    let offchainBalance:String
    
    init(dictionary: [String: Any]) {
        onchainBalance = dictionary["onchainBalance"] as? String ?? "0.00000000"
        offchainBalance = dictionary["offchainBalance"] as? String ?? "0.00000000"
    }
    
    public var description: String {
        return ""
    }
    
}
