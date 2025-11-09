//
//  DescriptorStruct.swift
//  FullyNoded2
//
//  Created by Peter on 15/02/20.
//  Copyright © 2020 Blockchain Commons, LLC. All rights reserved.
//
import LibWally

public struct Descriptor: CustomStringConvertible {
    
    let isCosigner:Bool
    let scriptType:String
    let format:String
    let isHot:Bool
    let mOfNType:String
    let chain:String
    let isMulti:Bool
    let isBIP67:Bool
    let isBIP49:Bool
    let isBIP84:Bool
    let isBIP48:Bool
    let isBIP44:Bool
    let isP2WPKH:Bool
    let isP2PKH:Bool
    let isP2SHP2WPKH:Bool
    let isP2TR:Bool
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
    let pubkey:String
    let isTaproot:Bool
    let index: Int?
    let string: String
    
    init(_ descriptor: String) {
        string = descriptor
        
        var dictionary = [String:Any]()
        
        if descriptor.contains("&") {
            dictionary["isSpecter"] = true
            
        } else {
            dictionary["isSpecter"] = false
            
        }
        
        isTaproot = descriptor.hasPrefix("tr(")
        isP2TR = isTaproot
        
        if descriptor.contains("multi") {
            dictionary["isMulti"] = true
            dictionary["isBIP67"] = descriptor.contains("sortedmulti")
            
            
            let arr = descriptor.split(separator: "(")
            for (i, item) in arr.enumerated() {
                if i == 0 {
                    
                    switch item {
                    
                    case "multi":
                        dictionary["format"] = "Bare-multi"
                        dictionary["scriptType"] = "Bare multi-sig"
                        
                    case "wsh":
                        dictionary["format"] = "P2WSH"
                        dictionary["scriptType"] = "Segwit multi-sig"
                        
                    case "sh":
                        if arr[1] == "wsh" {
                            dictionary["format"] = "P2SH-P2WSH"
                            dictionary["scriptType"] = "Nested multi-sig"
                            
                        } else {
                            dictionary["format"] = "P2SH"
                            dictionary["scriptType"] = "Legacy multi-sig"
                            
                        }
                        
                    default:
                        break
                    }
                }
                
                switch item {
                                
                case "multi", "sortedmulti":
                    let mofnarray = (arr[i + 1]).split(separator: ",")
                    let numberOfKeys = mofnarray.count - 1
                    dictionary["mOfNType"] = "\(mofnarray[0]) of \(numberOfKeys)"
                    dictionary["sigsRequired"] = UInt(mofnarray[0])
                    var keysWithPath = [String]()
                    for (i, item) in mofnarray.enumerated() {
                        if i != 0 {
                            keysWithPath.append("\(item)")
                        }
                        if i + 1 == mofnarray.count {
                            dictionary["keysWithPath"] = keysWithPath
                        }
                    }
                    
                    var fingerprints = [String]()
                    var keyArray = [String]()
                    var paths = [String]()
                    var derivationArray = [String]()
                    
                    /// extracting the xpubs and their paths so we can derive the individual multisig addresses locally
                    for key in keysWithPath {
                        var path = ""
                        if key.contains("/") {
                            if key.contains("[") && key.contains("]") {
                                // remove the bracket with deriv/fingerprint
                                let arr = key.split(separator: "]")
                                let rootPath = arr[0].replacingOccurrences(of: "[", with: "")
                                
                                let rootPathArr = rootPath.split(separator: "/")
                                dictionary["index"] = Int(rootPathArr[rootPathArr.count - 1])
                                if rootPathArr.count > 0 {
                                    fingerprints.append("[\(rootPathArr[0])]")
                                }
                                
                                var deriv = "m"
                                for (i, rootPathItem) in rootPathArr.enumerated() {
                                    if i > 0 {
                                        deriv += "/" + "\(rootPathItem)"
                                    }
                                }
                                derivationArray.append(deriv)
                                
                                let processedKey = arr[1]
                                // it has a path
                                let pathArray = processedKey.split(separator: "/")
                                for pathItem in pathArray {
                                    if pathItem.contains("xpub") || pathItem.contains("tpub") || pathItem.contains("xprv") || pathItem.contains("tprv") {
                                        keyArray.append("\(pathItem.replacingOccurrences(of: "))", with: ""))")
                                    } else if pathItem.hasPrefix("0") {
                                        var pubkey = ""
                                        if pathItem.contains(")") {
                                            let arr = pathItem.split(separator: ")")
                                            pubkey = "\(arr[0])"
                                        } else {
                                            pubkey = "\(pathItem)"
                                        }
                                        if let pubkeyData = Data(hexString: pubkey) {
                                            if pubkeyData.count == 33 || pubkeyData.count == 65 {
                                                keyArray.append(pubkey)
                                            }
                                        }
                                    } else {
                                        if !pathItem.contains("*") {
                                            if path == "" {
                                                path = "\(pathItem)"
                                            } else {
                                                path += "/" + pathItem
                                            }
                                        } else {
                                            paths.append(path)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    dictionary["derivationArray"] = derivationArray
                    dictionary["multiSigKeys"] = keyArray
                    dictionary["multiSigPaths"] = paths
                    
                    var processed = fingerprints.description.replacingOccurrences(of: "[\"", with: "")
                    processed = processed.replacingOccurrences(of: "\"]", with: "")
                    processed = processed.replacingOccurrences(of: "\"", with: "")
                    dictionary["fingerprint"] = processed
                    
                    for deriv in derivationArray {
                        let withH = deriv.replacingOccurrences(of: "h", with: "'")
                        switch withH {
                        
                        case "m/48'/0'/0'/1'", "m/48'/1'/0'/1'":
                            dictionary["isBIP44"] = false
                            dictionary["isP2PKH"] = false
                            dictionary["isBIP84"] = false
                            dictionary["isP2WPKH"] = false
                            dictionary["isBIP49"] = false
                            dictionary["isP2SHP2WPKH"] = true
                            dictionary["isBIP48"] = true
                            dictionary["isAccount"] = true
                            
                        case "m/48'/0'/0'/2'", "m/48'/1'/0'/2'":
                            dictionary["isBIP44"] = false
                            dictionary["isP2PKH"] = false
                            dictionary["isBIP84"] = false
                            dictionary["isP2WPKH"] = true
                            dictionary["isBIP49"] = false
                            dictionary["isP2SHP2WPKH"] = false
                            dictionary["isBIP48"] = true
                            dictionary["isAccount"] = true
                            
                        case "m/44'/0'/0'", "m/44'/1'/0'":
                            dictionary["isBIP44"] = true
                            dictionary["isP2PKH"] = true
                            dictionary["isBIP84"] = false
                            dictionary["isP2WPKH"] = false
                            dictionary["isBIP49"] = false
                            dictionary["isP2SHP2WPKH"] = false
                            dictionary["isAccount"] = true
                            
                        case "m/84'/0'/0'", "m/84'/1'/0'":
                            dictionary["isBIP84"] = true
                            dictionary["isP2WPKH"] = true
                            dictionary["isBIP44"] = false
                            dictionary["isP2PKH"] = false
                            dictionary["isBIP49"] = false
                            dictionary["isP2SHP2WPKH"] = false
                            dictionary["isAccount"] = true
                            
                        case "m/49'/0'/0'", "m/49'/1'/0'":
                            dictionary["isBIP49"] = true
                            dictionary["isP2SHP2WPKH"] = true
                            dictionary["isBIP44"] = false
                            dictionary["isP2PKH"] = false
                            dictionary["isBIP84"] = false
                            dictionary["isP2WPKH"] = false
                            dictionary["isAccount"] = true
                            
                        default:
                            
                            break
                            
                        }
                        
                    }
                    
                default:
                    break
                }
            }
            
        } else {
            
            dictionary["isMulti"] = false
            dictionary["mOfNType"] = "Single Sig"
            
            if descriptor.contains("[") && descriptor.contains("]") {
                let arr1 = descriptor.split(separator: "[")
                dictionary["keysWithPath"] = ["[" + "\(arr1[1])"]
                let arr2 = arr1[1].split(separator: "]")
                let derivation = arr2[0]
                dictionary["prefix"] = "[\(derivation)]"
                let derivarr = derivation.split(separator: "/")
                let index = derivarr[derivarr.count - 1]
                dictionary["index"] = Int(index)
                dictionary["fingerprint"] = "\(derivarr[0])"
                let extendedKeyWithPath = arr2[1]
                let arr4 = extendedKeyWithPath.split(separator: "/")
                let extendedKey = arr4[0]
                if extendedKey.contains("tpub") || extendedKey.contains("xpub") {
                    dictionary["accountXpub"] = "\(extendedKey.replacingOccurrences(of: ")", with: ""))"
                } else if extendedKey.contains("tprv") || extendedKey.contains("xprv") {
                    dictionary["accountXprv"] = "\(extendedKey.replacingOccurrences(of: ")", with: ""))"
                    if let hdkey = try? HDKey(base58: String(extendedKey)) {
                        dictionary["accountXpub"] = hdkey.xpub
                    }
                } else {
                    let subarray = extendedKey.split(separator: "#")
                    if subarray.count == 2 {
                        dictionary["pubkey"] = "\("\(subarray[0])".replacingOccurrences(of: ")", with: ""))"
                    } else {
                        dictionary["pubkey"] = "\(extendedKey.replacingOccurrences(of: ")", with: ""))"
                    }
                }
                
                let arr3 = derivation.split(separator: "/")
                var path = "m"
                
                for (i, item) in arr3.enumerated() {
                    switch i {
                    
                    case 1:
                        path += "/" + item
                        
                    default:
                        if i != 0 {
                            path += "/" + item
                            
                            if i + 1 == arr3.count {
                                
                                dictionary["derivation"] = path
                                let pathH = path.replacingOccurrences(of: "h", with: "'")
                                
                                switch pathH {
                                
                                case "m/44'/0'/0'", "m/44'/1'/0'":
                                    dictionary["isBIP44"] = true
                                    dictionary["isP2PKH"] = true
                                    dictionary["isAccount"] = true
                                    
                                case "m/84'/0'/0'", "m/84'/1'/0'":
                                    dictionary["isBIP84"] = true
                                    dictionary["isP2WPKH"] = true
                                    dictionary["isAccount"] = true
                                    
                                case "m/49'/0'/0'", "m/49'/1'/0'":
                                    dictionary["isBIP49"] = true
                                    dictionary["isP2SHP2WPKH"] = true
                                    dictionary["isAccount"] = true
                                    
                                case "m/86'/0'/0'", "m/86'1'/0'":
                                    dictionary["isBIP86"] = true
                                    dictionary["isAccount"] = true
                                    
                                default:
                                    
                                    break
                                    
                                }
                                
                            }
                            
                        } else {
                            break
                            
                        }
                        
                    }
                    
                }
                
            }
            
            dictionary["isCosigner"] = false
            
            if descriptor.contains("combo") {
                dictionary["format"] = "Combo"
            } else {
                let arr = descriptor.split(separator: "(")
                
                for (i, item) in arr.enumerated() {
                    
                    if i == 0 {
                        switch item {
                        case "tr":
                            dictionary["format"] = "P2TR"
                            dictionary["scriptType"] = "Taproot"
                        case "wsh":
                            dictionary["format"] = "P2WSH"
                            dictionary["scriptType"] = "Segwit multi-sig"
                            dictionary["isCosigner"] = true
                            
                        case "wpkh":
                            dictionary["format"] = "P2WPKH"
                            dictionary["isP2WPKH"] = true
                            dictionary["scriptType"] = "Segwit single-sig"
                            
                        case "sh":
                            if arr[1] == "wpkh" {
                                dictionary["format"] = "P2SH-P2WPKH"
                                dictionary["isP2SHP2WPKH"] = true
                                dictionary["scriptType"] = "Nested single-sig"
                            } else if arr[1] == "wsh" {
                                dictionary["format"] = "P2SH-P2WSH"
                                dictionary["scriptType"] = "Segwit multi-sig"
                                dictionary["isCosigner"] = true
                            } else {
                                dictionary["format"] = "P2SH"
                                dictionary["scriptType"] = "Legacy multi-sig"
                                dictionary["isCosigner"] = true
                            }
                            
                        case "pk":
                            dictionary["format"] = "P2PK"
                            dictionary["scriptType"] = "Public key"
                            
                        case "pkh":
                            dictionary["format"] = "P2PKH"
                            dictionary["isP2PKH"] = true
                            dictionary["scriptType"] = "Legacy single-sig"
                            
                        default:
                            
                            break
                            
                        }
                    }
                }
            }
        }
        
        if descriptor.contains("xpub") || descriptor.contains("xprv") {
            dictionary["chain"] = "Mainnet"
            dictionary["isHD"] = true
            
        } else if descriptor.contains("tpub") || descriptor.contains("tprv") {
            dictionary["chain"] = "Testnet"
            dictionary["isHD"] = true
            
        } else {
            dictionary["isHD"] = false
        }
        
        if descriptor.contains("xprv") || descriptor.contains("tprv") {
            dictionary["isHot"] = true
            
        } else {
            dictionary["isHot"] = false
        }
        
        isCosigner = dictionary["isCosigner"] as? Bool ?? false
        format = dictionary["format"] as? String ?? ""
        scriptType = dictionary["scriptType"] as? String ?? ""
        mOfNType = dictionary["mOfNType"] as? String ?? ""
        isHot = dictionary["isHot"] as? Bool ?? false
        chain = dictionary["chain"] as? String ?? ""
        isMulti = dictionary["isMulti"] as? Bool ?? false
        isBIP67 = dictionary["isBIP67"] as? Bool ?? false
        isBIP49 = dictionary["isBIP49"] as? Bool ?? false
        isBIP84 = dictionary["isBIP84"] as? Bool ?? false
        isBIP48 = dictionary["isBIP48"] as? Bool ?? false
        isBIP44 = dictionary["isBIP44"] as? Bool ?? false
        isP2PKH = dictionary["isP2PKH"] as? Bool ?? false
        isP2WPKH = dictionary["isP2WPKH"] as? Bool ?? false
        isP2SHP2WPKH = dictionary["isP2SHP2WPKH"] as? Bool ?? false
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
        pubkey = dictionary["pubkey"] as? String ?? ""
        index = dictionary["index"] as? Int
    }
    
    public var description: String {
        return ""
    }
    
}

