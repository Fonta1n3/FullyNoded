//
//  ImportStruct.swift
//  BitSense
//
//  Created by Peter on 19/10/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

public struct ImportStruct: CustomStringConvertible {
    
    public var description = ""
    
    let addToKeyPool:Bool
    let isInternal:Bool
    let timeStamp:Int
    let label:String
    let descriptor:String
    let isWatchOnly:Bool
    let isScript:Bool
    let convertedRange:[Int]
    let address:String
    let script:String
    let range:String
    let derivation:String
    let isTestnet:Bool
    let bip84:Bool
    let bip44:Bool
    let bip32:Bool
    let isHDMusig:Bool
    let key:String
    let fingerprint:String
    
    init(dictionary: [String:Any]) {
        
        addToKeyPool = dictionary["addToKeypool"] as? Bool ?? false
        isInternal = dictionary["addAsChange"] as? Bool ?? false
        timeStamp = dictionary["rescanDate"] as? Int ?? 0
        label = dictionary["label"] as? String ?? ""
        descriptor = dictionary["descriptor"] as? String ?? ""
        isWatchOnly = dictionary["isWatchOnly"] as? Bool ?? true
        isScript = dictionary["isscript"] as? Bool ?? false
        range = dictionary["range"] as? String ?? ""
        address = dictionary["address"] as? String ?? ""
        script = dictionary["redeemScript"] as? String ?? ""
        derivation = dictionary["derivation"] as? String ?? ""
        isTestnet = dictionary["isTestnet"] as? Bool ?? false
        convertedRange = dictionary["convertedRange"] as? [Int] ?? [0,0]
        bip32 = dictionary["bip32Segwit"] as? Bool ?? false
        bip44 = dictionary["bip44"] as? Bool ?? false
        bip84 = dictionary["bip84"] as? Bool ?? false
        isHDMusig = dictionary["isHDMusig"] as? Bool ?? false
        key = dictionary["key"] as? String ?? ""
        fingerprint = dictionary["fingerprint"] as? String ?? ""
        
    }
    
}
