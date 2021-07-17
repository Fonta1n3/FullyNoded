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
    
    static func parseUr(urString: String) -> [String]? {
        switch urString {
        case _ where urString.hasPrefix("ur:crypto-hdkey"):
            if let descriptor = parseHdkey(urString: urString) {
                return [descriptor]
            } else {
                return nil
            }
            
        case _ where urString.hasPrefix("ur:crypto-account"):
            if let keyArray = parseCryptoAccount(urString) {
                return keyArray
            } else {
                return nil
            }
            
        case _ where urString.hasPrefix("ur:crypto-output"):
            if let descriptor = parseCryptoOutput(urString) {
                return [descriptor]
            } else {
                return nil
            }
            
        default:
            return nil
        }
    }
    
    static func parseCryptoOutput(_ urString: String) -> String? {
        var descriptor:String?
        
        guard let ur = try? URDecoder.decode(urString.condenseWhitespace()),
              let decodedCbor = try? CBOR.decode(ur.cbor.bytes),
              case let CBOR.tagged(tag, taggedCbor) = decodedCbor else {// only accept wsh
            return nil
        }
        
        switch tag.rawValue {
        case 400:
            // script-hash
            if case let CBOR.tagged(embeddedTag, embeddedCbor) = taggedCbor {
                switch embeddedTag {
                case 406: // multisig
                    return parseMultisig(isBIP67: false, script: "sh", cbor: embeddedCbor)
                    
                case 407: // sortedmulti
                    return parseMultisig(isBIP67: true, script: "sh", cbor: embeddedCbor)
                    
                case 404:
                    // sh(wpkh())
                    do {
                        let key = try HDKey_(taggedCBOR: embeddedCbor)
                        guard let origin = key.origin, let extKey = key.base58 else { fallthrough }
                        return "sh(wpkh([\(origin.sourceFingerprint!.description)/\(origin)]\(extKey)/0/*))"
                    } catch {
                        print(error)
                        return nil
                    }
                case 303:
                    // sh()
                    do {
                        let key = try HDKey_(taggedCBOR: taggedCbor)
                        guard let origin = key.origin, let extKey = key.base58 else { fallthrough }
                        return "sh([\(origin.sourceFingerprint!.description)/\(origin)]\(extKey)/0/*)"
                    } catch {
                        print(error)
                        return nil
                    }
                case 401:
                    // sh(wsh())
                    if case let CBOR.tagged(embeddedTag_, embeddedCbor_) = embeddedCbor {
                        switch embeddedTag_ {
                        case 406:
                            return parseMultisig(isBIP67: false, script: "sh(wsh(multi()))", cbor: embeddedCbor_)
                        case 407:
                            return parseMultisig(isBIP67: true, script: "sh(wsh(sortedmulti()))", cbor: embeddedCbor_)
                        case 303:
                            do {
                                let key = try HDKey_(taggedCBOR: embeddedCbor)
                                guard let origin = key.origin, let extKey = key.base58 else { fallthrough }
                                return "sh(wsh([\(origin.sourceFingerprint!.description)/\(origin)]\(extKey)/0/*))"
                            } catch {
                                print(error)
                                return nil
                            }
                        default:
                            return nil
                        }
                    }
                    
                default:
                    return nil
                }
            }

        case 401:
            // wsh()
            if case let CBOR.tagged(embeddedTag, embeddedCbor) = taggedCbor {
                switch embeddedTag {
                case 406:
                    return parseMultisig(isBIP67: false, script: "wsh(multi())", cbor: embeddedCbor)
                case 407:
                    return parseMultisig(isBIP67: true, script: "wsh(sortedmulti())", cbor: embeddedCbor)
                case 303:
                    do {
                        let key = try HDKey_(taggedCBOR: taggedCbor)
                        guard let origin = key.origin, let extKey = key.base58 else { fallthrough }
                        return "wsh([\(origin.sourceFingerprint!.description)/\(origin)]\(extKey)/0/*)"
                    } catch {
                        print(error)
                        return nil
                    }
                default:
                    return nil
                }
            } else {
                return nil
            }
            
        case 403:
            // pkh()
            do {
                let key = try HDKey_(taggedCBOR: taggedCbor)
                guard let origin = key.origin, let extKey = key.base58 else { fallthrough }
                return "pkh([\(origin.sourceFingerprint!.description)/\(origin)]\(extKey)/0/*)"
            } catch {
                print(error)
                return nil
            }
        case 404:
            // wpkh()
            do {
                let key = try HDKey_(taggedCBOR: taggedCbor)
                guard let origin = key.origin, let extKey = key.base58 else { fallthrough }
                descriptor = "wpkh([\(origin.sourceFingerprint!.description)/\(origin)]\(extKey)/0/*)"
            } catch {
                print(error)
            }

        default:
            break
        }
        
        return descriptor
    }
    
    static func parseMultisig(isBIP67: Bool, script: String, cbor: CBOR) -> String? {
        guard case let CBOR.map(map) = cbor else { return nil }
        
        var thresholdCheck:Int?
        var keys = ""
        
        for (key, value) in map {
            switch key {
            case 1:
                guard case let CBOR.unsignedInt(thresholdRaw) = value else { fallthrough }
                
                thresholdCheck = Int(thresholdRaw)

            case 2:
                guard case let CBOR.array(hdkeysCbor) = value else { fallthrough }

                for hdkey in hdkeysCbor {
                    guard let hdkey = try? HDKey_.init(cbor: hdkey),
                          let xpub = hdkey.base58,
                          let origin = hdkey.origin else {
                        return nil
                    }
                    
                    keys += "," + "[\(origin.description)]" + xpub + "/0/*"
                }
                
            default:
                break
            }
        }
        
        guard let threshold = thresholdCheck else { return nil }
        
        switch script {
        case "wsh(multi())":
            return "wsh(multi(\(threshold)\(keys)))"
        case "wsh(sortedmulti())":
            return "wsh(sortedmulti(\(threshold)\(keys)))"
        case "sh(wsh(sortedmulti()))":
            return "sh(wsh(sortedmulti(\(threshold)\(keys))))"
        case "sh(wsh(multi()))":
            return "sh(wsh(multi(\(threshold)\(keys))))"
        case "sh(sortedmulti())":
            return "sh(sortedmulti(\(threshold)\(keys)))"
        case "sh(multi())":
            return "sh(multi(\(threshold)\(keys)))"
        default:
            return nil
        }
    }
    
    static func parseCryptoAccount(_ urString: String) -> [String]? {
        guard let ur = try? URDecoder.decode(urString.condenseWhitespace()),
              let decodedCbor = try? CBOR.decode(ur.cbor.bytes),
              case let CBOR.map(dict) = decodedCbor else {
            
            return nil
        }
        
        var xfp:String?
        var descriptorArray:[String] = []
        
        for (key, value) in dict {
            
            switch key {
            case 1:
                guard case let CBOR.unsignedInt(fingerprint) = value else { fallthrough }
                
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
                                    do {
                                        let key = try HDKey_(taggedCBOR: embeddedCbor)
                                        guard let origin = key.origin, let extKey = key.base58 else { fallthrough }
                                        let decriptor = "sh(wpkh([_xfp_/\(origin)]\(extKey)/0/*))"
                                        descriptorArray.append(decriptor)
                                    } catch {
                                        print(error)
                                    }
                                case 303:
                                    // sh()
                                    do {
                                        let key = try HDKey_(taggedCBOR: taggedCbor)
                                        guard let origin = key.origin, let extKey = key.base58 else { fallthrough }
                                        let decriptor = "sh([_xfp_/\(origin)]\(extKey)/0/*)"
                                        descriptorArray.append(decriptor)
                                    } catch {
                                        print(error)
                                    }
                                case 401:
                                    // sh(wsh())
                                    do {
                                        let key = try HDKey_(taggedCBOR: embeddedCbor)
                                        guard let origin = key.origin, let extKey = key.base58 else { fallthrough }
                                        let decriptor = "sh(wsh([_xfp_/\(origin)]\(extKey)/0/*))"
                                        descriptorArray.append(decriptor)
                                    } catch {
                                        print(error)
                                    }
                                default:
                                    break
                                }
                            }
                            
                        case 401:
                            // wsh()
                            do {
                                let key = try HDKey_(taggedCBOR: taggedCbor)
                                guard let origin = key.origin, let extKey = key.base58 else { fallthrough }
                                let decriptor = "wsh([_xfp_/\(origin)]\(extKey)/0/*)"
                                descriptorArray.append(decriptor)
                            } catch {
                                print(error)
                            }
                        case 403:
                            // pkh()
                            do {
                                let key = try HDKey_(taggedCBOR: taggedCbor)
                                guard let origin = key.origin, let extKey = key.base58 else { fallthrough }
                                let decriptor = "pkh([_xfp_/\(origin)]\(extKey)/0/*)"
                                descriptorArray.append(decriptor)
                            } catch {
                                print(error)
                            }
                        case 404:
                            // wpkh()
                            do {
                                let key = try HDKey_(taggedCBOR: taggedCbor)
                                guard let origin = key.origin, let extKey = key.base58 else { fallthrough }
                                let decriptor = "wpkh([_xfp_/\(origin)]\(extKey)/0/*)"
                                descriptorArray.append(decriptor)
                            } catch {
                                print(error)
                            }
                            
                        default:
                            break
                        }
                    }
                    
                    if i + 1 == accounts.count, let xfp = xfp {
                        for (d, descriptor) in descriptorArray.enumerated() {
                            let desc = descriptor.replacingOccurrences(of: "_xfp_", with: xfp)
                            descriptorArray[d] = desc
                        }
                    }
                }
            default:
                break
            }
        }
                
        return descriptorArray
    }
        
    static func parseHdkey(urString: String) -> String? {
        var descriptor:String?
        guard let ur = try? URDecoder.decode(urString.condenseWhitespace()),
              let decodedCbor = try? CBOR.decode(ur.cbor.bytes),
              let hdkey = try? HDKey_.init(cbor: decodedCbor),
              let origin = hdkey.origin else {
            return nil
        }
        
        let path = origin.description
                        
        switch path {
        case _ where path.contains("44'/0'/0'") || path.contains("44'/1'/0'"):
            guard let pkh = pkhDesc(key: hdkey) else { return nil }
            
            descriptor = pkh
            
        case _ where path.contains("84'/0'/0'") || path.contains("84'/1'/0'"):
            guard let wpkh = wpkhDesc(key: hdkey) else { return nil }
            
            descriptor = wpkh
            
        case _ where path.contains("49'/0'/0'") || path.contains("49'/1'/0'"):
            guard let shwpkh = shwpkhDesc(key: hdkey) else { return nil }
            
            descriptor = shwpkh
            
        case _ where path.contains("45'/0'/0'") || path.contains("45'/1'/0'"):
            guard let sh = shDesc(key: hdkey) else { return nil }
            
            descriptor = sh
            
        case _ where path.contains("48'/0'/0'/1'") || path.contains("48'/1'/0'/1'"):
            guard let shwsh = shwshDesc(key: hdkey) else { return nil }
            
            descriptor = shwsh
            
        case _ where path.contains("48'/0'/0'/2'") || path.contains("48'/1'/0'/2'"):
            guard let wsh = wshDesc(key: hdkey) else { return nil }
            
            descriptor = wsh
            
        default:
            break
        }
        
        return descriptor
    }
    
    static func pkhDesc(key: HDKey_) -> String? {
        guard let origin = key.origin,
              let extKey = key.base58 else {
            return nil
        }
        
        var fingerprint = "00000000"
        
        if let xfp = key.parentFingerprint {
            fingerprint = xfp.description
        }
        
        return "pkh([\(fingerprint)/\(origin)]\(extKey)/0/*)"
    }
    
    static func wpkhDesc(key: HDKey_) -> String? {
        guard let origin = key.origin,
              let extKey = key.base58 else {
            return nil
        }
        
        var fingerprint = "00000000"
        
        if let xfp = key.parentFingerprint {
            fingerprint = xfp.description
        }
        
        return "wpkh([\(fingerprint)/\(origin)]\(extKey)/0/*)"
    }
    
    static func shwpkhDesc(key: HDKey_) -> String? {
        guard let origin = key.origin,
              let extKey = key.base58 else {
            return nil
        }
        
        var fingerprint = "00000000"
        
        if let xfp = key.parentFingerprint {
            fingerprint = xfp.description
        }
        
        return "sh(wpkh([\(fingerprint)/\(origin)]\(extKey)/0/*))"
    }
    
    static func shDesc(key: HDKey_) -> String? {
        guard let origin = key.origin,
              let extKey = key.base58 else {
            return nil
        }
        
        var fingerprint = "00000000"
        
        if let xfp = key.parentFingerprint {
            fingerprint = xfp.description
        }
        
        return "sh([\(fingerprint)/\(origin)]\(extKey)/0/*)"
    }
    
    static func shwshDesc(key: HDKey_) -> String? {
        guard let origin = key.origin,
              let extKey = key.base58 else {
            return nil
        }
        
        var fingerprint = "00000000"
        
        if let xfp = key.parentFingerprint {
            fingerprint = xfp.description
        }
        
        return "sh(wsh([\(fingerprint)/\(origin)]\(extKey)/0/*))"
    }
    
    static func wshDesc(key: HDKey_) -> String? {
        guard let origin = key.origin,
              let extKey = key.base58 else {
            return nil
        }
        
        var fingerprint = "00000000"
        
        if let xfp = key.parentFingerprint {
            fingerprint = xfp.description
        }
        
        return "wsh([\(fingerprint)/\(origin)]\(extKey)/0/*)"
    }
    
}
