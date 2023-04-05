//
//  NodeStruct.swift
//  BitSense
//
//  Created by Peter on 18/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

public struct NodeStruct: CustomStringConvertible {
    
    let id:UUID?
    let label:String
    let isActive:Bool
    let onionAddress:Data?
    let rpcpassword:Data?
    let rpcuser:Data?
    let isLightning:Bool
    let uncleJim:Bool
    let macaroon:Data?
    let cert:Data?
    let isJoinMarket:Bool
    let isNostr:Bool
    let nostrPubkey:Data?
    let nostrPrivkey:Data?
    let subscribeTo:Data?
    let nostrWords:Data?
    
    init(dictionary: [String: Any]) {
        id = dictionary["id"] as? UUID
        label = dictionary["label"] as? String ?? ""
        isActive = dictionary["isActive"] as? Bool ?? false
        onionAddress = dictionary["onionAddress"] as? Data
        rpcpassword = dictionary["rpcpassword"] as? Data
        rpcuser = dictionary["rpcuser"] as? Data
        isLightning = dictionary["isLightning"] as? Bool ?? false
        uncleJim = dictionary["uncleJim"] as? Bool ?? false
        macaroon = dictionary["macaroon"] as? Data
        cert = dictionary["cert"] as? Data
        isJoinMarket = dictionary["isJoinMarket"] as? Bool ?? false
        isNostr = dictionary["isNostr"] as? Bool ?? false
        nostrPubkey = dictionary["nostrPubkey"] as? Data
        nostrPrivkey = dictionary["nostrPrivkey"] as? Data
        subscribeTo = dictionary["subscribeTo"] as? Data
        nostrWords = dictionary["nostrWords"] as? Data
    }
    
    public var description: String {
        return ""
    }
    
}

