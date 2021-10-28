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
            .unsignedInt(1) : .byteString(data.bytes),
        ])
        let cbor = Data(wrapper.cborEncode())
        do {
            let rawUr = try UR(type: "crypto-seed", cbor: cbor)
            return UREncoder.encode(rawUr)
        } catch {
            return nil
        }
    }
    
    static func urToEntropy(urString: String) -> (data: Data?, birthdate: UInt64?) {
        do {
            let ur = try URDecoder.decode(urString)
            let decodedCbor = try CBOR.decode(ur.cbor.bytes)
            guard case let CBOR.map(dict) = decodedCbor! else { return (nil, nil) }
            var data:Data?
            var birthdate:UInt64?
            for (key, value) in dict {
                switch key {
                case 1:
                    guard case let CBOR.byteString(byteString) = value else { fallthrough }
                    data = Data(byteString)
                case 2:
                    guard case let CBOR.unsignedInt(n) = value else { fallthrough }
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
        guard let ur = ur(urString), let decodedCbor = try? CBOR.decode(ur.cbor.bytes),
            case let CBOR.byteString(bytes) = decodedCbor,
            let text = Data(bytes).utf8 else {
                return (nil, "Unable to decode the QR code into a text file.")
        }
        return (text, nil)
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
            return parseMultisig(isBIP67: false, script: "sh", cbor: embeddedCbor)
            
        case 407: // sortedmulti
            return parseMultisig(isBIP67: true, script: "sh", cbor: embeddedCbor)
            
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
    
    static func descriptorToHdKeyCbor(_ descriptor: Descriptor) -> CBOR? {
        let key = descriptor.accountXpub
        
        /// Decodes our original extended key to base58 data.
        let b58 = Base58.decode(key)
        let b58Data = Data(b58)
        let depth = b58Data.subdata(in: Range(4...4))
        let parentFingerprint = b58Data.subdata(in: Range(5...8))
        let chaincode = b58Data.subdata(in: Range(13...44))
        let keydata = b58Data.subdata(in: Range(45...77))
        
        var cointype:UInt64 = 1
        if descriptor.chain == "main" {
            cointype = 0
        }
        
        var originsArray:[OrderedMapEntry] = []
        originsArray.append(.init(key: 1, value: .array(origins(path: descriptor.derivation))))
        originsArray.append(.init(key: 2, value: .unsignedInt(UInt64(descriptor.fingerprint, radix: 16) ?? 0)))
        originsArray.append(.init(key: 3, value: .unsignedInt(UInt64(depth.hexString) ?? 0)))
        let originsWrapper = CBOR.orderedMap(originsArray)
        
        let useInfoWrapper:CBOR = .map([
            .unsignedInt(2) : .unsignedInt(cointype)
        ])
        
        guard let hexValue = UInt64(parentFingerprint.hexString, radix: 16) else { return nil }
        
        var hdkeyArray:[OrderedMapEntry] = []
        hdkeyArray.append(.init(key: 1, value: .boolean(false)))
        hdkeyArray.append(.init(key: 2, value: .boolean(false)))
        hdkeyArray.append(.init(key: 3, value: .byteString([UInt8](keydata))))
        hdkeyArray.append(.init(key: 4, value: .byteString([UInt8](chaincode))))
        hdkeyArray.append(.init(key: 5, value: .tagged(CBOR.Tag(rawValue: 305), useInfoWrapper)))
        hdkeyArray.append(.init(key: 6, value: .tagged(CBOR.Tag(rawValue: 304), originsWrapper)))
        hdkeyArray.append(.init(key: 8, value: .unsignedInt(hexValue)))
        
        return CBOR.orderedMap(hdkeyArray)
    }
    
    static func taggedHdKeyCbor(_ descriptor: Descriptor) -> CBOR? {
        guard let cbor = descriptorToHdKeyCbor(descriptor) else { return nil }
        
        return .tagged(CBOR.Tag(rawValue: 303), cbor)
    }
    
    
    static func descriptorToUrHdkey(_ descriptor: Descriptor) -> String? {
        guard let cbor = descriptorToHdKeyCbor(descriptor),
              let rawUr = try? UR(type: "crypto-hdkey", cbor: cbor) else {
                  return nil
              }
        
        return UREncoder.encode(rawUr)
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
        
        // MARK: TODO UPDATE TO BE DYNAMIC FOR NON SORTED MULTI
        if descriptor.isBIP67 {
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
        
        var keyThreshholdArray:[OrderedMapEntry] = []
        keyThreshholdArray.append(.init(key: 1, value: .unsignedInt(UInt64(threshold))))
        keyThreshholdArray.append(.init(key: 2, value: .array(hdkeyArray)))
        let keyThreshholdArrayCbor = CBOR.orderedMap(keyThreshholdArray)
        
        let sortedMultisigTag:CBOR.Tag = .init(rawValue: 407)
        let taggedMsigCbor:CBOR = .tagged(sortedMultisigTag, keyThreshholdArrayCbor)
        
        var scriptTag:CBOR.Tag
        
        switch descriptor {
        case _ where descriptor.format == "P2WSH":
            scriptTag = .init(rawValue: 401)
            return .tagged(scriptTag, taggedMsigCbor)
            
        case _ where descriptor.format == "P2SH-P2WSH":
            let outerScriptTag:CBOR.Tag = .init(rawValue: 400)
            let tagged = CBOR.tagged(outerScriptTag, taggedMsigCbor)
            scriptTag = .init(rawValue: 404)
            return .tagged(scriptTag, tagged)
            
        case _ where descriptor.format == "P2SH":
            scriptTag = .init(rawValue: 400)
            return .tagged(scriptTag, taggedMsigCbor)
            
        default:
            return nil
        }
        
    }
    
    static func cosignerOutputCbor(_ descriptor: Descriptor) -> CBOR? {
        switch descriptor {
        case _ where descriptor.format == "P2WPKH":
            let wpkhTag:CBOR.Tag = .init(rawValue: 404)
            guard let hdkeyCbor = taggedHdKeyCbor(descriptor) else { return nil }
            
            return .tagged(wpkhTag, hdkeyCbor)
            
        case _ where descriptor.format == "P2WSH":
            let wshTag:CBOR.Tag = .init(rawValue: 401)
            guard let hdkeyCbor = taggedHdKeyCbor(descriptor) else { return nil }
            
            return .tagged(wshTag, hdkeyCbor)
            
        default:
            return nil
        }
    }
    
    static func cborOutputToCryptoAccount(_ cryptoOutputCbor: CBOR, _ descriptor: Descriptor) -> String? {
        guard let hexValue = UInt64(descriptor.fingerprint, radix: 16) else { return nil }
        
        var cborArray:[OrderedMapEntry] = []
        cborArray.append(.init(key: 1, value: .unsignedInt(hexValue)))
        cborArray.append(.init(key: 2, value: .array([cryptoOutputCbor])))
        
        let cbor = CBOR.orderedMap(cborArray)
        
        guard let rawUr = try? UR(type: "crypto-account", cbor: cbor) else {
            return nil
        }
  
        return UREncoder.encode(rawUr)
    }
    
    static func origins(path: String) -> [CBOR] {
        var cborArray:[CBOR] = []
        for (i, item) in path.split(separator: "/").enumerated() {
            if i != 0 && item != "m" {
                if item.contains("h") {
                    let processed = item.split(separator: "h")
                    
                    if let int = Int("\(processed[0])") {
                        let unsignedInt = CBOR.unsignedInt(UInt64(int))
                        cborArray.append(unsignedInt)
                        cborArray.append(CBOR.boolean(true))
                    }
                    
                } else if item.contains("'") {
                    let processed = item.split(separator: "'")
                    
                    if let int = Int("\(processed[0])") {
                        let unsignedInt = CBOR.unsignedInt(UInt64(int))
                        cborArray.append(unsignedInt)
                        cborArray.append(CBOR.boolean(true))
                    }
                } else {
                    if let int = Int("\(item)") {
                        let unsignedInt = CBOR.unsignedInt(UInt64(int))
                        cborArray.append(unsignedInt)
                        cborArray.append(CBOR.boolean(false))
                    }
                }
            }
        }
        
        return cborArray
    }
    
}
