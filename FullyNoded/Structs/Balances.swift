//
//  Balances.swift
//  BitSense
//
//  Created by Peter on 27/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

public struct Balances: CustomStringConvertible {
    
    let coldBalance:String
    let unconfirmedBalance:String
    let hotBalance:String
    
    init(dictionary: [String: Any]) {
        self.coldBalance = dictionary["coldBalance"] as? String ?? "0.00000000"
        self.unconfirmedBalance = dictionary["unconfirmedBalance"] as? String ?? "0.00000000"
        self.hotBalance = dictionary["hotBalance"] as? String ?? "0.00000000"
    }
    public var description: String {
        return ""
    }
}
