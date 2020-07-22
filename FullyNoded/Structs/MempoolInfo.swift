//
//  MempoolInfo.swift
//  BitSense
//
//  Created by Peter on 27/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

public struct MempoolInfo: CustomStringConvertible {
    
    let mempoolCount:Int
    
    init(dictionary: [String: Any]) {
        self.mempoolCount = dictionary["mempoolCount"] as? Int ?? 0
    }
    
    public var description: String {
        return ""
    }
    
}
