//
//  HomeTableStruct.swift
//  BitSense
//
//  Created by Peter on 26/08/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation


public struct HomeStruct: CustomStringConvertible {
    
    let network:String
    let hashrate:String
    let amount:Double
    let coldBalance:String
    let version:String
    let torReachable:Bool
    let incomingCount:Int
    let outgoingCount:Int
    let blockheight:Int
    let difficulty:String
    let size:String
    let progress:String
    let pruned:Bool
    let unconfirmedBalance:String
    let hotBalance:String
    let mempoolCount:Int
    let transactions:[[String: Any]]
    let uptime:Int
    let feeRate:String
    let actualProgress:Double
    
    init(dictionary: [String: Any]) {
        
        self.feeRate = dictionary["feeRate"] as? String ?? ""
        self.uptime = dictionary["uptime"] as? Int ?? 0
        self.network = dictionary["chain"] as? String ?? ""
        self.hashrate = dictionary["networkhashps"] as? String ?? ""
        self.amount = dictionary["amount"] as? Double ?? 0.0
        self.coldBalance = dictionary["coldBalance"] as? String ?? "0.00000000"
        self.version = dictionary["subversion"] as? String ?? ""
        self.torReachable = dictionary["reachable"] as? Bool ?? false
        self.incomingCount = dictionary["incomingCount"] as? Int ?? 0
        self.outgoingCount = dictionary["outgoingCount"] as? Int ?? 0
        self.blockheight = dictionary["blocks"] as? Int ?? 0
        self.difficulty = dictionary["difficulty"] as? String ?? ""
        self.size = dictionary["size"] as? String ?? ""
        self.progress = dictionary["progress"] as? String ?? ""
        self.pruned = dictionary["pruned"] as? Bool ?? false
        self.unconfirmedBalance = dictionary["unconfirmedBalance"] as? String ?? "0.00000000"
        self.hotBalance = dictionary["hotBalance"] as? String ?? "0.00000000"
        self.mempoolCount = dictionary["mempoolCount"] as? Int ?? 0
        self.transactions = dictionary["transactions"] as? [[String: Any]] ?? []
        self.actualProgress = dictionary["actualProgress"] as? Double ?? 0.0
        
    }
    
    public var description: String {
        return ""
    }
    
}
