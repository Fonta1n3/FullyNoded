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
    
    enum scriptTag: Tag {
        case wpkh = 404
        case wsh = 401
        case sh = 400
        case multi = 406
        case sortedmulti = 407
        case pk = 402
        case pkh = 403
        case combo = 405
        case addr = 307
        case raw = 408
        case tr = 409
    }
    
    static func bytesToData(_ ur: UR) -> Data? {
        guard case let CBOR.bytes(bytes) = ur.cbor else { return nil }
        
        return Data(bytes)
    }
    
    static func ur(_ string: String) -> UR? {
        
        return try? UR(urString: string)
    }
    
    static func dataToUrBytes(_ data: Data) -> UR? {
        
        return try? UR(type: "bytes", untaggedCBOR: data)
    }
    
    static func psbtUr(_ data: Data) -> UR? {
        //guard case let CBOR.bytes(bytes) = ur.cbor else { return nil }
        
        return try? UR(type: "crypto-psbt", cbor: data.cbor)
    }
    
    static func psbtUrToBase64Text(_ ur: UR) -> String? {
        guard case let CBOR.bytes(bytes) = ur.cbor else { return nil }
        
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
            
        case _ where lowercased.hasPrefix("ur:crypto-seed"):
            guard let words = cryptoSeedToMnemonic(urString) else { return (nil, "Error deriving descriptors from cytpo-seed.") }
            
            let (descriptors, errMess) = Keys.descriptorsFromSigner(words)
            return (descriptors, errMess)
        
        default:
            return (nil, "Unsupported UR type. Please let us know about it on Twitter, Telegram or Github.")
        }
    }
    
    static func cryptoSeedToMnemonic(_ cryptoSeed: String) -> String? {
        guard let data = URHelper.urToEntropy(urString: cryptoSeed).data,
              let words = Keys.dataToSigner(data) else { return nil }
        
        return words
    }
    
    static func mnemonicToCryptoSeed(_ words: String) -> String? {
        guard let entropy = Keys.wordsToEntropy(words) else { return nil }
        
        return URHelper.entropyToUr(data: entropy.data)
    }
    
    static func entropyToUr(data: Data) -> String? {
        let wrapper:CBOR = .map([
            CBOR.unsigned(1) : data.cborData
        ])
        
        let cbor = wrapper.cbor
        
        guard let rawUr = try? UR(type: "crypto-seed", cbor: cbor) else { return nil }
        
        return UREncoder.encode(rawUr)
        
//        let wrapper:CBOR = .map([
//            .unsignedInt(1) : .byteString(data.bytes)
//        ])
//        let cbor = Data(wrapper.cborEncode())
//        do {
//            let rawUr = try UR(type: "crypto-seed", cbor: cbor)
//            return UREncoder.encode(rawUr)
//        } catch {
//            return nil
//        }
    }
    
    static func urToEntropy(urString: String) -> (data: Data?, birthdate: UInt64?) {
        do {
            let ur = try URDecoder.decode(urString)
            let decodedCbor = ur.cbor//try CBOR.decode(ur.cbor.bytes)
            guard case let CBOR.map(dict) = decodedCbor else { return (nil, nil) }
            
            var data:Data?
            var birthdate:UInt64?
            
            for (key, value) in dict {
                switch key {
                case 1:
                    guard case let CBOR.bytes(byteString) = value else { fallthrough }
                    
                    data = byteString
                case 2:
                    guard case let CBOR.unsigned(n) = value else { fallthrough }

                    birthdate = n
                default:
                    break
                }
            }
            return (data, birthdate)
        } catch {
            return (nil, nil)
        }
    }
        
    static func parseBlueWalletCoordinationSetup(_ urString: String) -> (text: String?, error: String?) {
        guard let ur = try? UR(urString: urString) else { return ((nil, "Unable to convert string to UR."))}
        
        guard case let CBOR.bytes(bytes) = ur.cbor else { return ((nil, "Unable to convert UR to bytes.")) }
        
        guard let text = bytes.utf8String else { return ((nil, "Unable to convert ur to text."))}
        
        return (text, nil)
    }
    
    static func parseCryptoOutput(_ urString: String) -> (descriptors: [String]?, error: String?) {
        guard let ur = try? UR(urString: urString) else { return ((nil, "Unable to convert string to UR."))}
        
        
        guard case let CBOR.tagged(tag, taggedCbor) = ur.cbor else { return((nil, "Unable to convert ")) }
        
//        guard let ur = try? URDecoder.decode(urString.condenseWhitespace()),
//              let decodedCbor = try? CBOR.decode(ur.cbor.bytes),
//              case let CBOR.tagged(tag, taggedCbor) = decodedCbor else {
//            return (nil, "Error decoding your output UR.")
//        }
        
        switch tag {
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
            
        case 409:
            // tr()
            return parseTRCbor(taggedCbor: taggedCbor)

        default:
            return (nil, "Unsupported script type for output. Please let us know about it on Twitter, Github or Telegram.")
        }
    }
    
    static func parseTRCbor(taggedCbor: CBOR) -> (descriptors: [String]?, error: String?) {
        guard let key = try? HDKey_(taggedCBOR: taggedCbor),
              let origin = key.origin,
              let extKey = key.base58 else {
            return (nil, "Error deriving hdkey/origin/xpub from your taproot CBOR.")
        }
        
        return (["tr([\(origin)]\(extKey)/0/*)"], nil)
    }
    
    static func parseWPKHCbor(taggedCbor: CBOR) -> (descriptors: [String]?, error: String?) {
        print("taggedCbor: \(taggedCbor)")
        
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
        case 401:
            return parseWSHCbor(taggedCbor: embeddedCbor)
        case 303:
            if let desc = parsePlainWSHCbor(taggedCbor: taggedCbor) {
                return ([desc], nil)
            } else {
                return (nil, "Unable to parse that crypto-hdkey, please reach out to us.")
            }
                        
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
        
        var childPath = "/0/*"
        
        if let children = key.children {
            childPath = children.description
        }
        
        return "wsh([\(origin)]\(extKey)\(childPath))"
    }
    
    static func parseSHCbor(taggedCbor: CBOR) -> (descriptors: [String]?, error: String?) {
        guard case let CBOR.tagged(embeddedTag, embeddedCbor) = taggedCbor else { return (nil, "No tagged CBOR in your script hash UR.") }
        
        switch embeddedTag {
        case 406: // multisig
            return parseMultisig(isBIP67: false, script: "sh(multi())", cbor: embeddedCbor)
            
        case 407: // sortedmulti
            return parseMultisig(isBIP67: true, script: "sh(sortedmulti())", cbor: embeddedCbor)
            
        case 404: // sh(wpkh())
            return parseSHWPKHCbor(embeddedCbor: embeddedCbor)
            
        case 401:
            // sh(wsh())
            return parseWSHCbor(taggedCbor: embeddedCbor)
            
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
        case 303:
            if let desc = parsePlainSHWSHCbor(embeddedCbor: embeddedCbor) {
                return ([desc], nil)
            } else {
                return (nil, "Unable to parse that crypto-hdkey, please reach out to us.")
            }
            
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
        
        var childPath = "/0/*"
        
        if let children = key.children {
            childPath = children.description
        }
        
        return "sh(wsh([\(origin)]\(extKey)\(childPath))"
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
                guard case let CBOR.unsigned(thresholdRaw) = value else {
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
        guard let ur = try? UR(urString: urString) else { return ((nil, "Unable to convert string to UR."))}
        
        guard case let CBOR.map(dict) = ur.cbor else {
            
            return (nil, "Error decoding account UR.")
        }
        
        var error:String?
        var xfp:String?
        var descriptorArray:[String] = []
        var arrayToReturn:[String]?
        
        for (key, value) in dict {
            
            switch key {
            case 1:
                guard case let CBOR.unsigned(fingerprint) = value else {
                    error = "Unable to decode the master key fingerprint."
                    fallthrough
                }
                
                xfp = String(Int(fingerprint), radix: 16)
                
            case 2:
                guard case let CBOR.array(accounts) = value else { fallthrough }
                
                for (i, elem) in accounts.enumerated() {
                    if case let CBOR.tagged(tag, taggedCbor) = elem {
                        switch tag {
                            
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
        guard let ur = try? UR(urString: urString) else { return ((nil, "Unable to convert string to UR."))}
        let decodedCbor = ur.cbor
        guard let hdkey = try? HDKey_.init(cbor: decodedCbor) else { return ((nil, "Unable to init hdkey from deocedCbor"))}
        guard let origin = hdkey.origin else { return ((nil, "Unable to get origin from hdkey."))}
        
//        guard let ur = try? URDecoder.decode(urString.condenseWhitespace()),
//              let decodedCbor = try? CBOR.decode(ur.cbor.bytes),
//              let hdkey = try? HDKey_.init(cbor: decodedCbor),
//              let origin = hdkey.origin else {
//            return (nil, "UR decoding/hdkey/conversion/origin missing.")
//        }
        
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
    
    static func extractExtendedKey(_ key: String) -> (chaincode: Data?, keyData: Data?, parentFingerprint: Data?, depth: Data?) {
        let b58 = Base58.decode(key)
        let b58Data = Data(b58)
        let depth = b58Data.subdata(in: Range(4...4))
        let parentFingerprint = b58Data.subdata(in: Range(5...8))
        let chaincode = b58Data.subdata(in: Range(13...44))
        let keydata = b58Data.subdata(in: Range(45...77))
        return (chaincode, keydata, parentFingerprint, depth)
    }
    
    static func descriptorToHdKeyCbor(_ descriptor: Descriptor) -> CBOR? {
        var key:String!
        var isPrivate:Bool!
        var cointype:UInt64 = 1
        
        if descriptor.chain == "Mainnet" {
            cointype = 0
        }
        
        if descriptor.accountXpub != "" {
            key = descriptor.accountXpub
            isPrivate = false
        } else if descriptor.accountXprv != "" {
            key = descriptor.accountXprv
            isPrivate = true
        }
        
        /// Decodes our original extended key to base58 data.
        let (chaincode, keyData, parentFingerprint, depth) = extractExtendedKey(key)
        
        guard let chaincode = chaincode,
                let keyData = keyData,
                let parentFingerprint = parentFingerprint,
                let depth = depth else {
                    
            return nil
        }
        
//        var originsArray:[OrderedMapEntry] = []
//        originsArray.append(.init(key: 1, value: .array(origins(path: descriptor.derivation))))
//        originsArray.append(.init(key: 2, value: .unsignedInt(UInt64(descriptor.fingerprint, radix: 16) ?? 0)))
//        originsArray.append(.init(key: 3, value: .unsignedInt(UInt64(depth.hexString) ?? 0)))
//        let originsWrapper = CBOR.orderedMap(originsArray)
        
        let originsWrapper: CBOR = .map([
            CBOR.unsigned(1): CBOR.array(origins(path: descriptor.derivation)),
            CBOR.unsigned(2): CBOR.unsigned(UInt64(descriptor.fingerprint, radix: 16) ?? 0),
            CBOR.unsigned(3): CBOR.unsigned(UInt64(depth.hexString) ?? 0)
        ])
        
        let useInfoWrapper:CBOR = .map([
            CBOR.unsigned(2) : CBOR.unsigned(cointype)
        ])
        
        guard let hexValue = UInt64(parentFingerprint.hexString, radix: 16) else { return nil }
        
//        var hdkeyArray:[OrderedMapEntry] = []
//        hdkeyArray.append(.init(key: 1, value: .boolean(false)))
//        hdkeyArray.append(.init(key: 2, value: .boolean(isPrivate)))
//        hdkeyArray.append(.init(key: 3, value: .byteString([UInt8](keyData))))
//        hdkeyArray.append(.init(key: 4, value: .byteString([UInt8](chaincode))))
//        hdkeyArray.append(.init(key: 5, value: .tagged(CBOR.Tag(rawValue: 305), useInfoWrapper)))
//        hdkeyArray.append(.init(key: 6, value: .tagged(CBOR.Tag(rawValue: 304), originsWrapper)))
//        hdkeyArray.append(.init(key: 8, value: .unsignedInt(hexValue)))
        var hdkeyMap: CBOR = .map([
            CBOR.unsigned(1): CBOR(booleanLiteral: false),
            CBOR.unsigned(2): CBOR(booleanLiteral: isPrivate),
            CBOR.unsigned(3): CBOR.bytes(keyData),
            CBOR.unsigned(4): CBOR.bytes(chaincode),
            CBOR.unsigned(5): CBOR.tagged(305, useInfoWrapper),
            CBOR.unsigned(6): CBOR.tagged(304, originsWrapper),
            CBOR.unsigned(8): CBOR.unsigned(hexValue)
        ])
        
        return hdkeyMap
    }
    
    static func taggedHdKeyCbor(_ descriptor: Descriptor) -> CBOR? {
        guard let cbor = descriptorToHdKeyCbor(descriptor) else { return nil }
        
        return CBOR.tagged(303, cbor)
        //return .tagged(CBOR.Tag(rawValue: 303), cbor)
    }
    
    
    static func descriptorToUrHdkey(_ descriptor: Descriptor) -> String? {
        guard let cbor = descriptorToHdKeyCbor(descriptor),
              let rawUr = try? UR(type: "crypto-hdkey", cbor: cbor) else {
                  return nil
              }
        
        return UREncoder.encode(rawUr)
    }
    
    static func rootXpubToUrHdkey(_ xpub: String) -> String? {
        let descriptor = "wsh([00000000]\(xpub))"
        return descriptorToUrHdkey(Descriptor(descriptor))
    }
    
    static func descriptorToUrOutput(_ descriptor: Descriptor) -> String? {
        guard let cbor = descriptorToOutputCbor(descriptor),
              let rawUr = try? UR(type: "crypto-output", cbor: cbor) else {
                  return nil
              }
        
        return UREncoder.encode(rawUr)
    }
    
    static func descriptorToUrAccount(_ descriptor: Descriptor) -> String? {
        guard let cbor = descriptorToOutputCbor(descriptor) else { return nil }
        
        return cborOutputToCryptoAccount(cbor, descriptor)
    }
    
    static func descriptorToOutputCbor(_ descriptor: Descriptor) -> CBOR? {
        var cbor:CBOR? = nil
        
        if descriptor.isMulti {
            cbor = multiSigOutputCbor(descriptor)
        } else {
            cbor = cosignerOutputCbor(descriptor)
        }
        
        return cbor
    }
    
    static func multiSigOutputCbor(_ descriptor: Descriptor) -> CBOR? {
        let threshold = descriptor.sigsRequired
        
        var hdkeyArray:[CBOR] = []
        
        for key in descriptor.keysWithPath {
            let hack = "wsh(\(key)"
    
            guard let hdkey = taggedHdKeyCbor(Descriptor(hack)) else { return nil }
            
            hdkeyArray.append(hdkey)
        }
        
//        var keyThreshholdArray:[OrderedMapEntry] = []
//        keyThreshholdArray.append(.init(key: 1, value: .unsignedInt(UInt64(threshold))))
//        keyThreshholdArray.append(.init(key: 2, value: .array(hdkeyArray)))
//        let keyThreshholdArrayCbor = CBOR.orderedMap(keyThreshholdArray)
        
        var keyThreshholdMap: CBOR = .map([
            CBOR.unsigned(1): CBOR.unsigned(UInt64(threshold)),
            CBOR.unsigned(2): CBOR.array(hdkeyArray),
        ])
        
        var multisigTag: UInt64
        
        if descriptor.isBIP67 {
            multisigTag = 407
        } else {
            multisigTag = 406
        }
        
        let taggedMsigCbor:CBOR = .tagged(Tag(multisigTag), keyThreshholdMap)
        
        switch descriptor {
        case _ where descriptor.format == "P2WSH":
            return .tagged(scriptTag.wsh.rawValue, taggedMsigCbor)
            
        case _ where descriptor.format == "P2SH-P2WSH":
            let tagged = CBOR.tagged(scriptTag.sh.rawValue, taggedMsigCbor)
            return .tagged(scriptTag.wsh.rawValue, tagged)
            
        case _ where descriptor.format == "P2SH":
            return .tagged(scriptTag.sh.rawValue, taggedMsigCbor)
            
        default:
            return nil
        }
        
    }
    
    static func cosignerOutputCbor(_ descriptor: Descriptor) -> CBOR? {
        guard let hdkeyCbor = taggedHdKeyCbor(descriptor) else { return nil }
        
        switch descriptor {
        case _ where descriptor.format == "P2WPKH":
            return .tagged(scriptTag.wpkh.rawValue, hdkeyCbor)
            
        case _ where descriptor.format == "Combo":
            return .tagged(scriptTag.combo.rawValue, hdkeyCbor)
            
        case _ where descriptor.format == "P2WSH":
            return .tagged(scriptTag.wsh.rawValue, hdkeyCbor)
            
        case _ where descriptor.format == "P2SH-P2WPKH":
            let innerTagged = CBOR.tagged(scriptTag.wpkh.rawValue, hdkeyCbor)
            
            return .tagged(scriptTag.sh.rawValue, innerTagged)
            
        case _ where descriptor.format == "P2SH-P2WSH":
            let innerTagged = CBOR.tagged(scriptTag.wsh.rawValue, hdkeyCbor)
            
            return .tagged(scriptTag.sh.rawValue, innerTagged)
            
        case _ where descriptor.format == "P2SH":
            return .tagged(scriptTag.sh.rawValue, hdkeyCbor)
            
        case _ where descriptor.format == "P2TR":
            return .tagged(scriptTag.tr.rawValue, hdkeyCbor)
            
        case _ where descriptor.format == "P2PKH":
            return .tagged(scriptTag.pkh.rawValue, hdkeyCbor)
            
        default:
            return nil
        }
    }
    
    static func cborOutputToCryptoAccount(_ cryptoOutputCbor: CBOR, _ descriptor: Descriptor) -> String? {
        guard let hexValue = UInt64(descriptor.fingerprint, radix: 16) else { return nil }
//        var cborArray:[OrderedMapEntry] = []
//        cborArray.append(.init(key: 1, value: .unsignedInt(hexValue)))
//        cborArray.append(.init(key: 2, value: .array([cryptoOutputCbor])))
        
        var cborMap: CBOR = .map([
            CBOR.unsigned(1): CBOR.unsigned(hexValue),
            CBOR.unsigned(2): CBOR.array([cryptoOutputCbor])
        ])
        
        //let cbor = CBOR.orderedMap(cborArray)
        
        guard let rawUr = try? UR(type: "crypto-account", cbor: cborMap) else { return nil }
  
        return UREncoder.encode(rawUr)
    }
    
    static func origins(path: String) -> [CBOR] {
        var cborArray:[CBOR] = []
        for (i, item) in path.split(separator: "/").enumerated() {
            if i != 0 && item != "m" {
                if item.contains("h") {
                    let processed = item.split(separator: "h")
                    
                    if let int = Int("\(processed[0])") {
                        let unsignedInt = CBOR.unsigned(UInt64(int))
                        cborArray.append(unsignedInt)
                        cborArray.append(CBOR(booleanLiteral: true))
                    }
                    
                } else if item.contains("'") {
                    let processed = item.split(separator: "'")
                    
                    if let int = Int("\(processed[0])") {
                        let unsignedInt = CBOR.unsigned(UInt64(int))
                        cborArray.append(unsignedInt)
                        cborArray.append(CBOR(booleanLiteral: true))
                    }
                } else {
                    if let int = Int("\(item)") {
                        let unsignedInt = CBOR.unsigned(UInt64(int))
                        cborArray.append(unsignedInt)
                        cborArray.append(CBOR(booleanLiteral: false))
                    }
                }
            }
        }
        
        return cborArray
    }
    
}
