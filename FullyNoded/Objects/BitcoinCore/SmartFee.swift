//
//  SmartFee.swift
//  BitSense
//
//  Created by Peter on 27/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

public struct FeeInfo: CustomStringConvertible {
    
    let feeRate:String
    
    init(dictionary: [String: Any]) {
        self.feeRate = dictionary["feeRate"] as? String ?? ""
    }
    
    public var description: String {
        return ""
    }
}
