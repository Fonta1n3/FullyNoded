//
//  AccountMap.swift
//  FullyNoded
//
//  Created by Peter Denton on 7/17/24.
//  Copyright © 2024 Fontaine. All rights reserved.
//

import Foundation

public struct AccountMapStr: CustomStringConvertible {
    
    let descriptor: String
    let label: String?
    let blockheight: Int?
    
    init(dictionary: [String: Any]) {
        descriptor = dictionary["descriptor"] as! String
        label = dictionary["label"] as? String
        blockheight = dictionary["blockheight"] as? Int
    }
    
    public var description: String {
        return ""
    }
    
}
