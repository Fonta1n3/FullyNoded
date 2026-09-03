//
//  Timelocks.swift
//  FullyNoded
//
//  Created by Peter Denton on 7/25/26.
//  Copyright © 2026 Fontaine. All rights reserved.
//

import Foundation

public struct Timelock: CustomStringConvertible {
    
    let id:UUID
    let descriptor:String
    
    init(dictionary: [String: Any]) {
        id = dictionary["id"] as! UUID
        descriptor = dictionary["descriptor"] as! String
    }
    
    public var description: String {
        return ""
    }
}
