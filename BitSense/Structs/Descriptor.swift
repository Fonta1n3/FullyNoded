//
//  DescriptorStruct.swift
//  FullyNoded2
//
//  Created by Peter on 15/02/20.
//  Copyright © 2020 Blockchain Commons, LLC. All rights reserved.
//

public struct Descriptor: CustomStringConvertible {
    
    let format:String
    let isHot:Bool
    let mOfNType:String
    let chain:String
    let isMulti:Bool
    let isBIP67:Bool
    let isBIP49:Bool
    let isBIP84:Bool
    let isBIP44:Bool
    let isP2WPKH:Bool
    let isP2PKH:Bool
    let isP2SHP2WPKH:Bool
    let network:String
    let multiSigKeys:[String]
    let multiSigPaths:[String]
    let sigsRequired:UInt
    let accountXpub:String
    let accountXprv:String
    let derivation:String
    let derivationArray:[String]
    let isSpecter:Bool
    let isHD:Bool
    let keysWithPath:[String]
    let isAccount:Bool
    let fingerprint:String
    let prefix:String
    
    init(dictionary: [String: Any]) {
        format = dictionary["format"] as? String ?? ""
        mOfNType = dictionary["mOfNType"] as? String ?? ""
        isHot = dictionary["isHot"] as? Bool ?? false
        chain = dictionary["chain"] as? String ?? ""
        isMulti = dictionary["isMulti"] as? Bool ?? false
        isBIP67 = dictionary["isBIP67"] as? Bool ?? false
        isBIP49 = dictionary["isBIP49"] as? Bool ?? false
        isBIP84 = dictionary["isBIP84"] as? Bool ?? false
        isBIP44 = dictionary["isBIP44"] as? Bool ?? false
        isP2PKH = dictionary["isP2PKH"] as? Bool ?? false
        isP2WPKH = dictionary["isP2WPKH"] as? Bool ?? false
        isP2SHP2WPKH = dictionary["isP2SHP2WPKH"] as? Bool ?? false
        network = dictionary["network"] as? String ?? ""
        multiSigKeys = dictionary["multiSigKeys"] as? [String] ?? [""]
        multiSigPaths = dictionary["multiSigPaths"] as? [String] ?? [""]
        sigsRequired = dictionary["sigsRequired"] as? UInt ?? 0
        accountXpub = dictionary["accountXpub"] as? String ?? ""
        accountXprv = dictionary["accountXprv"] as? String ?? ""
        derivation = dictionary["derivation"] as? String ?? ""
        derivationArray = dictionary["derivationArray"] as? [String] ?? [""]
        isSpecter = dictionary["isSpecter"] as? Bool ?? false
        isHD = dictionary["isHD"] as? Bool ?? false
        keysWithPath = dictionary["keysWithPath"] as? [String] ?? [""]
        isAccount = dictionary["isAccount"] as? Bool ?? false
        fingerprint = dictionary["fingerprint"] as? String ?? ""
        prefix = dictionary["prefix"] as? String ?? ""
    }
    
    public var description: String {
        return ""
    }
    
}

