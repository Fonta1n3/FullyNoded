//
//  UR.swift
//  FullyNoded
//
//  Created by Peter on 10/10/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation
import URKit

class URHelper {
    static func bytesToData(_ ur: UR) -> Data? {
        guard let decodedCbor = try? CBOR.decode(ur.cbor.bytes),
            case let CBOR.byteString(bytes) = decodedCbor else {
                return nil
        }
        
        return Data(bytes)
    }
    
    static func ur(_ string: String) -> UR? {
        return try? UR(urString: string)
    }
    
    static func dataToUrBytes(_ data: Data) -> UR? {
        let cbor = CBOR.byteString(data.bytes).cborEncode().data
        
        return try? UR(type: "bytes", cbor: cbor)
    }
    
    static func psbtUr(_ data: Data) -> UR? {
        let cbor = CBOR.encodeByteString(data.bytes).data
        
        return try? UR(type: "crypto-psbt", cbor: cbor)
    }
    
    static func psbtUrToBase64Text(_ ur: UR) -> String? {
        guard let decodedCbor = try? CBOR.decode(ur.cbor.bytes),
            case let CBOR.byteString(bytes) = decodedCbor else {
                return nil
        }
        
        return Data(bytes).base64EncodedString()
    }
    
    static func parseUr(urString: String) -> (descriptors: [String]?, error: String?) {
        let lowercased = urString.lowercased()
        
        switch lowercased {
        case _ where lowercased.hasPrefix("ur:crypto-hdkey"):
            return parseHdkey(urString: urString)
            
        case _ where lowercased.hasPrefix("ur:crypto-account"):
            return parseCryptoAccount(urString)
            
        case _ where lowercased.hasPrefix("ur:crypto-output"):
            return parseCryptoOutput(urString)
        
        default:
            return (nil, "Unsupported UR type. Please let us know about it on Twitter, Telegram or Github.")
        }
    }
        
    static func parseBlueWalletCoordinationSetup(_ urString: String) -> (text: String?, error: String?) {
        guard let ur = ur(urString), let decodedCbor = try? CBOR.decode(ur.cbor.bytes),
            case let CBOR.byteString(bytes) = decodedCbor,
            let textFile = Data(bytes).utf8 else {
                return (nil, "Unable to decode the QR code into a text file.")
        }
        
        return (textFile, nil)
    }
    
    static func parseCryptoOutput(_ urString: String) -> (descriptors: [String]?, error: String?) {
        guard let ur = try? URDecoder.decode(urString.condenseWhitespace()),
              let decodedCbor = try? CBOR.decode(ur.cbor.bytes),
              case let CBOR.tagged(tag, taggedCbor) = decodedCbor else {
            return (nil, "Error decoding your output UR.")
        }
        
        switch tag.rawValue {
        case 400:
            // script-hash
            return parseSHCbor(taggedCbor: taggedCbor)

        case 401:
            // wsh()
            return parseWSHCbor(taggedCbor: taggedCbor)
            
        case 403:
            // pkh()
            return parsePKHCbor(taggedCbor: taggedCbor)
        case 404:
            // wpkh()
            return parseWPKHCbor(taggedCbor: taggedCbor)

        default:
            return (nil, "Unsupported script type for output. Please let us know about it on Twitter, Github or Telegram.")
        }
    }
    
    static func parseWPKHCbor(taggedCbor: CBOR) -> (descriptors: [String]?, error: String?) {
        guard let key = try? HDKey_(taggedCBOR: taggedCbor),
              let origin = key.origin,
              let extKey = key.base58 else {
            return (nil, "Error deriving hdkey/origin/xpub from your witness public key hash CBOR.")
        }
        
        return (["wpkh([\(origin)]\(extKey)/0/*)"], nil)
    }
    
    static func parsePKHCbor(taggedCbor: CBOR) -> (descriptors: [String]?, error: String?) {
        guard let key = try? HDKey_(taggedCBOR: taggedCbor),
              let origin = key.origin,
              let extKey = key.base58 else {
            return (nil, "Error deriving hdkey/origin/xpub from your public key hash CBOR.")
        }
        
        return (["pkh([\(origin)]\(extKey)/0/*)"], nil)
    }
    
    static func parseWSHCbor(taggedCbor: CBOR) -> (descriptors: [String]?, error: String?) {
        guard case let CBOR.tagged(embeddedTag, embeddedCbor) = taggedCbor else {
            return (nil, "No tagged CBOR in your witness script hash CBOR.")
        }
        
        switch embeddedTag {
        case 406:
            return parseMultisig(isBIP67: false, script: "wsh(multi())", cbor: embeddedCbor)
        case 407:
            return parseMultisig(isBIP67: true, script: "wsh(sortedmulti())", cbor: embeddedCbor)
        default:
            return (nil, "Unsupported script. Fully Noded does not support single sig descriptors with multisig scripts.")
        }
    }
    
    static func parsePlainWSHCbor(taggedCbor: CBOR) -> String? {
        guard let key = try? HDKey_(taggedCBOR: taggedCbor),
              let origin = key.origin,
              let extKey = key.base58 else {
            return nil
        }
        
        return "wsh([\(origin)]\(extKey)/0/*)"
    }
    
    static func parseSHCbor(taggedCbor: CBOR) -> (descriptors: [String]?, error: String?) {
        guard case let CBOR.tagged(embeddedTag, embeddedCbor) = taggedCbor else { return (nil, "No tagged CBOR in your script hash UR.") }
        
        switch embeddedTag {
        case 406: // multisig
            return parseMultisig(isBIP67: false, script: "sh", cbor: embeddedCbor)
            
        case 407: // sortedmulti
            return parseMultisig(isBIP67: true, script: "sh", cbor: embeddedCbor)
            
        case 404: // sh(wpkh())
            return parseSHWPKHCbor(embeddedCbor: embeddedCbor)
            
        case 303: // sh()
            return (nil, "Fully Noded does not support multisig scripts for single sig descriptors.")
            
        case 401:
            // sh(wsh())
            return (nil, "Fully Noded does not support multisig scripts for single sig descriptors.")
            
        default:
            return (nil, "Unsupported script hash. Please let us know about it on Twitter, Github or Telegram.")
        }
    }
    
    static func parseSHWSHCbor(embeddedCbor: CBOR) -> (descriptors: [String]?, error: String?) {
        guard case let CBOR.tagged(embeddedTag_, embeddedCbor_) = embeddedCbor else {
            return (nil, "No tagged CBOR in your script hash witness script hash UR.")
        }
        
        switch embeddedTag_ {
        case 406:
            return parseMultisig(isBIP67: false, script: "sh(wsh(multi()))", cbor: embeddedCbor_)
        case 407:
            return parseMultisig(isBIP67: true, script: "sh(wsh(sortedmulti()))", cbor: embeddedCbor_)
        default:
            return (nil, "Unsupported script type. Fully Noded does not support multisig scripts for single sig descriptors.")
        }
    }
    
    static func parsePlainSHWSHCbor(embeddedCbor: CBOR) -> String? {
            guard let key = try? HDKey_(taggedCBOR: embeddedCbor),
                  let origin = key.origin,
                  let extKey = key.base58 else {
                return nil
            }
        
            return "sh(wsh([\(origin)]\(extKey)/0/*))"
    }
    
    static func parsePlainSHCbor(taggedCbor: CBOR) -> String? {
        guard let key = try? HDKey_(taggedCBOR: taggedCbor),
              let origin = key.origin,
              let extKey = key.base58 else {
            return nil
        }
        
        return "sh([\(origin)]\(extKey)/0/*)"
    }
    
    static func parseSHWPKHCbor(embeddedCbor: CBOR) -> (descriptors: [String]?, error: String?) {
        guard let key = try? HDKey_(taggedCBOR: embeddedCbor),
              let origin = key.origin,
              let extKey = key.base58 else {
            return (nil, "Error deriving hdkey/origin/base58 from your script hash witness public key hash CBOR.")
        }
        
        return (["sh(wpkh([\(origin)]\(extKey)/0/*))"], nil)
    }
    
    static func parseMultisig(isBIP67: Bool, script: String, cbor: CBOR) -> (descriptors: [String]?, error: String?) {
        guard case let CBOR.map(map) = cbor else { return (nil, "No map found in your multisig UR.") }
        
        var thresholdCheck:Int?
        var keys = ""
        
        for (key, value) in map {
            switch key {
            case 1:
                guard case let CBOR.unsignedInt(thresholdRaw) = value else {
                    return (nil, "Invalid multisig hdkey, no threshold provided.")
                }
                
                thresholdCheck = Int(thresholdRaw)

            case 2:
                guard case let CBOR.array(hdkeysCbor) = value else { fallthrough }

                for hdkey in hdkeysCbor {
                    guard case let CBOR.tagged(tag, hdkeycbor) = hdkey else { fallthrough }
                    
                    if tag == 303 {
                        guard let hdkey = try? HDKey_.init(cbor: hdkeycbor),
                              let xpub = hdkey.base58,
                              let origin = hdkey.origin else {
                            
                            return (nil, "Error converting hdkey CBOR into xpub and origin.")
                        }
                        
                        guard origin.description != "" else {
                            return (nil, "Invalid hdkey, no origin info! Fully Noded does not support hdkeys with origin info missing.")
                        }
                        
                        var childPath = "/0/*"
                        
                        if let children = hdkey.children {
                            childPath = children.description
                        }
                                                
                        if let _ = origin.sourceFingerprint {
                            keys += "," + "[\(origin)]" + xpub + childPath
                        } else {
                            keys += "," + "[00000000/\(origin)]" + xpub + childPath
                        }
                    }
                }
                
            default:
                break
            }
        }
        
        guard let threshold = thresholdCheck else { return (nil, "Invalid multisig hdkey, no threshold provided.") }
        
        switch script {
        case "wsh(multi())":
            return (["wsh(multi(\(threshold)\(keys)))"], nil)
        case "wsh(sortedmulti())":
            return (["wsh(sortedmulti(\(threshold)\(keys)))"], nil)
        case "sh(wsh(sortedmulti()))":
            return (["sh(wsh(sortedmulti(\(threshold)\(keys))))"], nil)
        case "sh(wsh(multi()))":
            return (["sh(wsh(multi(\(threshold)\(keys))))"], nil)
        case "sh(sortedmulti())":
            return (["sh(sortedmulti(\(threshold)\(keys)))"], nil)
        case "sh(multi())":
            return (["sh(multi(\(threshold)\(keys)))"], nil)
        default:
            return (nil, "Unsupported multisig script. Please let us know about this via Twitter, Github or Telegram.")
        }
    }
    
    static func parseCryptoAccount(_ urString: String) -> (descriptors: [String]?, error: String?) {
        guard let ur = try? URDecoder.decode(urString.condenseWhitespace()),
              let decodedCbor = try? CBOR.decode(ur.cbor.bytes),
              case let CBOR.map(dict) = decodedCbor else {
            
            return (nil, "Error decoding account UR.")
        }
        
        var error:String?
        var xfp:String?
        var descriptorArray:[String] = []
        var arrayToReturn:[String]?
        
        for (key, value) in dict {
            
            switch key {
            case 1:
                guard case let CBOR.unsignedInt(fingerprint) = value else {
                    error = "Unable to decode the master key fingerprint."
                    fallthrough
                }
                
                xfp = String(Int(fingerprint), radix: 16)
                
            case 2:
                guard case let CBOR.array(accounts) = value else { fallthrough }
                
                for (i, elem) in accounts.enumerated() {
                    if case let CBOR.tagged(tag, taggedCbor) = elem {
                        
                        switch tag.rawValue {
                        case 400:
                            // script-hash
                            if case let CBOR.tagged(embeddedTag, embeddedCbor) = taggedCbor {
                                switch embeddedTag {
                                case 404:
                                    // sh(wpkh())
                                    if let key = try? HDKey_(taggedCBOR: embeddedCbor),
                                       let origin = key.origin,
                                       let extKey = key.base58 {
                                        
                                        if let _ = origin.sourceFingerprint {
                                            descriptorArray.append("sh(wpkh([\(origin)]\(extKey)/0/*))")
                                        } else {
                                            descriptorArray.append("sh(wpkh([_xfp_/\(origin)]\(extKey)/0/*))")
                                        }
                                    }
                                    
                                case 303:
                                    //sh()
                                    let (descArray, errorCheck) = parseSHCbor(taggedCbor: embeddedCbor)
                                    arrayToReturn = descArray
                                    error = errorCheck
                            
                                case 401:
                                    // sh(wsh())
                                    let (descArray, errorCheck) = parseSHWSHCbor(embeddedCbor: embeddedCbor)
                                    arrayToReturn = descArray
                                    error = errorCheck
                                    
                                default:
                                    break
                                }
                            }
                            
                        case 401:
                            // wsh()
                            let (descArray, errorCheck) = parseWSHCbor(taggedCbor: taggedCbor)
                            arrayToReturn = descArray
                            error = errorCheck
                            
                        case 403:
                            // pkh()
                            if let key = try? HDKey_(taggedCBOR: taggedCbor),
                               let origin = key.origin,
                               let extKey = key.base58 {
                                
                                if let _ = origin.sourceFingerprint {
                                    descriptorArray.append("pkh([\(origin)]\(extKey)/0/*)")
                                } else {
                                    descriptorArray.append("pkh([_xfp_/\(origin)]\(extKey)/0/*)")
                                }
                            }
                            
                        case 404:
                            // wpkh()
                            if let key = try? HDKey_(taggedCBOR: taggedCbor),
                               let origin = key.origin,
                               let extKey = key.base58 {
                                                                
                                if let _ = origin.sourceFingerprint {
                                    descriptorArray.append("wpkh([\(origin)]\(extKey)/0/*)")
                                } else {
                                    descriptorArray.append("wpkh([_xfp_/\(origin)]\(extKey)/0/*)")
                                }
                            }
                            
                        default:
                            break
                        }
                    }
                    
                    if i + 1 == accounts.count, let xfp = xfp {
                        for (d, descriptor) in descriptorArray.enumerated() {
                            let desc = descriptor.replacingOccurrences(of: "_xfp_", with: xfp)
                            descriptorArray[d] = desc
                            
                            if d + 1 == descriptorArray.count {
                                arrayToReturn = descriptorArray
                            }
                        }
                    }
                }
            default:
                break
            }
        }
                
        return (arrayToReturn, error)
    }
        
    static func parseHdkey(urString: String) -> (descriptors: [String]?, error: String?) {
        var descriptor:[String]?
        guard let ur = try? URDecoder.decode(urString.condenseWhitespace()),
              let decodedCbor = try? CBOR.decode(ur.cbor.bytes),
              let hdkey = try? HDKey_.init(cbor: decodedCbor),
              let origin = hdkey.origin else {
            return (nil, "UR decoding/hdkey/conversion/origin missing.")
        }
        
        let path = origin.description
                        
        switch path {
        case _ where path.contains("44'/0'/0'") || path.contains("44'/1'/0'"):
            guard let pkh = pkhDesc(key: hdkey) else { return (nil, "Error getting public key hash descriptor.") }
            
            descriptor = [pkh]
            
        case _ where path.contains("84'/0'/0'") || path.contains("84'/1'/0'"):
            guard let wpkh = wpkhDesc(key: hdkey) else { return (nil, "Error getting witness public key hash descriptor.") }
            
            descriptor = [wpkh]
            
        case _ where path.contains("49'/0'/0'") || path.contains("49'/1'/0'"):
            guard let shwpkh = shwpkhDesc(key: hdkey) else { return (nil, "Error getting script hash witness public key hash descriptor.") }
            
            descriptor = [shwpkh]
            
        case _ where path.contains("45'/0'/0'") || path.contains("45'/1'/0'"):
            guard let sh = shDesc(key: hdkey) else { return (nil, "Error getting script hash descriptor.") }
            
            descriptor = [sh]
            
        case _ where path.contains("48'/0'/0'/1'") || path.contains("48'/1'/0'/1'"):
            guard let shwsh = shwshDesc(key: hdkey) else { return (nil, "Error getting script hash dwitness script hash escriptor.") }
            
            descriptor = [shwsh]
            
        case _ where path.contains("48'/0'/0'/2'") || path.contains("48'/1'/0'/2'"):
            guard let wsh = wshDesc(key: hdkey) else { return (nil, "Error getting witness script hash descriptor.") }
            
            descriptor = [wsh]
            
        default:
            break
        }
        
        return (descriptor, nil)
    }
    
    static func pkhDesc(key: HDKey_) -> String? {
        guard let origin = key.origin,
              let extKey = key.base58 else {
            return nil
        }
        
        return "pkh([\(origin)]\(extKey)/0/*)"
    }
    
    static func wpkhDesc(key: HDKey_) -> String? {
        guard let origin = key.origin,
              let extKey = key.base58 else {
            return nil
        }
        
       return "wpkh([\(origin)]\(extKey)/0/*)"
    }
    
    static func shwpkhDesc(key: HDKey_) -> String? {
        guard let origin = key.origin,
              let extKey = key.base58 else {
            return nil
        }
        
        return "sh(wpkh([\(origin)]\(extKey)/0/*))"
    }
    
    static func shDesc(key: HDKey_) -> String? {
        guard let origin = key.origin,
              let extKey = key.base58 else {
            return nil
        }
        
        return "sh([\(origin)]\(extKey)/0/*)"
    }
    
    static func shwshDesc(key: HDKey_) -> String? {
        guard let origin = key.origin,
              let extKey = key.base58 else {
            return nil
        }
        
        return "sh(wsh([\(origin)]\(extKey)/0/*))"
    }
    
    static func wshDesc(key: HDKey_) -> String? {
        guard let origin = key.origin,
              let extKey = key.base58 else {
            return nil
        }
        
        return "wsh([\(origin)]\(extKey)/0/*)"
    }
    
}
