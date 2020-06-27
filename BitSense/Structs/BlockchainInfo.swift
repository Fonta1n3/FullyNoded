//
//  BlockchainInfo.swift
//  BitSense
//
//  Created by Peter on 27/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

public struct BlockchainInfo: CustomStringConvertible {
    
    let difficulty:String
    let network:String
    let blockheight:Int
    let size:String
    let progress:String
    let pruned:Bool
    let actualProgress:Double
    init(dictionary: [String: Any]) {
        
        self.network = dictionary["chain"] as? String ?? ""
        self.blockheight = dictionary["blocks"] as? Int ?? 0
        self.difficulty = dictionary["difficulty"] as? String ?? ""
        self.size = dictionary["size"] as? String ?? ""
        self.progress = dictionary["progress"] as? String ?? ""
        self.pruned = dictionary["pruned"] as? Bool ?? false
        self.actualProgress = dictionary["actualProgress"] as? Double ?? 0.0
        
    }
    
    public var description: String {
        return ""
    }
}
