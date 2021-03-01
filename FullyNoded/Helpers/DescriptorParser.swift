//
//  DescriptorParser.swift
//  FullyNoded2
//
//  Created by Peter on 15/02/20.
//  Copyright © 2020 Blockchain Commons, LLC. All rights reserved.
//

import Foundation

// MARK: This parser is designed to work with FullyNoded 2 descriptors, we try and make it extensible and this can be an area to be improved so that it handles any descriptor but for the purposes of the app we can make a few assumptions as we know what type of descriptors the wallet will produce.

// Examples:
/// pk(0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798)
///
/// pkh(02c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5)
///
/// wpkh(02f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9)
///
/// sh(wpkh(03fff97bd5755eeea420453a14355235d382f6472f8568a18b2f057a1460297556))
///
/// combo(0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798)
///
/// multi(1,022f8bde4d1a07209355b4a7250a5c5128e88b84bddc619ab7cba8d569b240efe4,025cbdf0646e5db4eaa398f365f2ea7a0e3d419b7e0330e39ce92bddedcac4f9bc)
///
/// sh(multi(2,022f01e5e15cca351daff3843fb70f3c2f0a1bdd05e5af888a67784ef3e10a2a01,03acd484e2f0c7f65309ad178a9f559abde09796974c57e714c35f110dfc27ccbe))
///
/// sh(sortedmulti(2,03acd484e2f0c7f65309ad178a9f559abde09796974c57e714c35f110dfc27ccbe,022f01e5e15cca351daff3843fb70f3c2f0a1bdd05e5af888a67784ef3e10a2a01))
/// wsh(multi(2,03a0434d9e47f3c86235477c7b1ae6ae5d3442d49b1943c2b752a68e2a47e247c7,03774ae7f858a9411e5ef4246b70c65aac5649980be5c17891bbec17895da008cb,03d01115d548e7561b15c38f004d734633687cf4419620095bc5b0f47070afe85a))
/// sh(wsh(multi(1,03f28773c2d975288bc7d1d205c3748651b075fbc6610e58cddeeddf8f19405aa8,03499fdf9e895e719cfd64e67f07d38e3226aa7b63678949e6e49b241a60e823e4,02d7924d4f7d43ea965a465ae3095ff41131e5946f3c85f79e44adbcf8e27e080e)))
///
/// pk(xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8)
///
/// pkh(xpub68Gmy5EdvgibQVfPdqkBBCHxA5htiqg55crXYuXoQRKfDBFA1WEjWgP6LHhwBZeNK1VTsfTFUHCdrfp1bgwQ9xv5ski8PX9rL2dZXvgGDnw/1'/2)
///
/// pkh([d34db33f/44'/0'/0']xpub6ERApfZwUNrhLCkDtcHTcxd75RbzS1ed54G1LkBUHQVHQKqhMkhgbmJbZRkrgZw4koxb5JaHWkY4ALHY2grBGRjaDMzQLcgJvLJuZZvRcEL/1/*)

/// wsh(multi(1,xpub661MyMwAqRbcFW31YEwpkMuc5THy2PSt5bDMsktWQcFF8syAmRUapSCGu8ED9W6oDMSgv6Zz8idoc4a6mr8BDzTJY47LJhkJ8UB7WEGuduB/1/0/*,xpub69H7F5d8KSRgmmdJg2KhpAK8SR3DjMwAdkxj3ZuxV27CprR9LgpeyGmXUbC6wb7ERfvrnKZjXoUmmDznezpbZb7ap6r1D3tgFxHmwMkQTPH/0/0/*))

///wsh(sortedmulti(1,xpub661MyMwAqRbcFW31YEwpkMuc5THy2PSt5bDMsktWQcFF8syAmRUapSCGu8ED9W6oDMSgv6Zz8idoc4a6mr8BDzTJY47LJhkJ8UB7WEGuduB/1/0/*,xpub69H7F5d8KSRgmmdJg2KhpAK8SR3DjMwAdkxj3ZuxV27CprR9LgpeyGmXUbC6wb7ERfvrnKZjXoUmmDznezpbZb7ap6r1D3tgFxHmwMkQTPH/0/0/*))

class DescriptorParser {
    
    func descriptor(_ descriptor: String) -> Descriptor {
        var dict = [String:Any]()
        
        if descriptor.contains("&") {
            dict["isSpecter"] = true
            
        } else {
            dict["isSpecter"] = false
            
        }
        
        if descriptor.contains("multi") {
            dict["isMulti"] = true
            dict["isBIP67"] = descriptor.contains("sortedmulti")
            
            let arr = descriptor.split(separator: "(")
            for (i, item) in arr.enumerated() {
                if i == 0 {
                    
                    switch item {
                        
                    case "multi":
                        dict["format"] = "Bare-multi"
                        
                    case "wsh":
                        dict["format"] = "P2WSH"
                        
                    case "sh":
                        if arr[1] == "wsh" {
                            dict["format"] = "P2SH-P2WSH"
                            
                        } else {
                            dict["format"] = "P2SH"
                            
                        }
                        
                    default:
                        break
                        
                    }
                    
                }
                
                switch item {
                    
                case "multi", "sortedmulti":
                    let mofnarray = (arr[i + 1]).split(separator: ",")
                    let numberOfKeys = mofnarray.count - 1
                    dict["mOfNType"] = "\(mofnarray[0]) of \(numberOfKeys)"
                    dict["sigsRequired"] = UInt(mofnarray[0])
                    var keysWithPath = [String]()
                    for (i, item) in mofnarray.enumerated() {
                        if i != 0 {
                            keysWithPath.append("\(item)")
                        }
                        if i + 1 == mofnarray.count {
                            dict["keysWithPath"] = keysWithPath
                        }
                    }
                     
                    var fingerprints = [String]()
                    var keyArray = [String]()
                    var paths = [String]()
                    var derivationArray = [String]()
                    
                    /// extracting the xpubs and their paths so we can derive the individual multisig addresses locally
                    for key in keysWithPath {
                        var path = String()
                        if key.contains("/") {
                            if key.contains("[") && key.contains("]") {
                                // remove the bracket with deriv/fingerprint
                                let arr = key.split(separator: "]")
                                let rootPath = arr[0].replacingOccurrences(of: "[", with: "")
                                
                                let rootPathArr = rootPath.split(separator: "/")
                                fingerprints.append("[\(rootPathArr[0])]")
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
                    
                    dict["derivationArray"] = derivationArray
                    dict["multiSigKeys"] = keyArray
                    dict["multiSigPaths"] = paths
                    
                    var processed = fingerprints.description.replacingOccurrences(of: "[\"", with: "")
                    processed = processed.replacingOccurrences(of: "\"]", with: "")
                    processed = processed.replacingOccurrences(of: "\"", with: "")
                    dict["fingerprint"] = processed
                    
                    for deriv in derivationArray {
                        print("deriv: \(deriv)")

                        switch deriv {
                            
                        case "m/48'/0'/0'/1'", "m/48'/1'/0'/1'":
                            dict["isBIP44"] = false
                            dict["isP2PKH"] = false
                            dict["isBIP84"] = false
                            dict["isP2WPKH"] = false
                            dict["isBIP49"] = false
                            dict["isP2SHP2WPKH"] = true
                            dict["isWIP48"] = true
                            dict["isAccount"] = true
                            
                        case "m/48'/0'/0'/2'", "m/48'/1'/0'/2'":
                            dict["isBIP44"] = false
                            dict["isP2PKH"] = false
                            dict["isBIP84"] = false
                            dict["isP2WPKH"] = true
                            dict["isBIP49"] = false
                            dict["isP2SHP2WPKH"] = false
                            dict["isWIP48"] = true
                            dict["isAccount"] = true
                            
                        case "m/44'/0'/0'", "m/44'/1'/0'":
                            dict["isBIP44"] = true
                            dict["isP2PKH"] = true
                            dict["isBIP84"] = false
                            dict["isP2WPKH"] = false
                            dict["isBIP49"] = false
                            dict["isP2SHP2WPKH"] = false
                            dict["isAccount"] = true

                        case "m/84'/0'/0'", "m/84'/1'/0'":
                            dict["isBIP84"] = true
                            dict["isP2WPKH"] = true
                            dict["isBIP44"] = false
                            dict["isP2PKH"] = false
                            dict["isBIP49"] = false
                            dict["isP2SHP2WPKH"] = false
                            dict["isAccount"] = true

                        case "m/49'/0'/0'", "m/49'/1'/0'":
                            dict["isBIP49"] = true
                            dict["isP2SHP2WPKH"] = true
                            dict["isBIP44"] = false
                            dict["isP2PKH"] = false
                            dict["isBIP84"] = false
                            dict["isP2WPKH"] = false
                            dict["isAccount"] = true

                        default:

                            break

                        }

                    }
                    
                default:
                    break
                }
            }
                        
        } else {
            
            dict["isMulti"] = false
            
            if descriptor.contains("[") && descriptor.contains("]") {
                
                let arr1 = descriptor.split(separator: "[")
                dict["keysWithPath"] = ["[" + "\(arr1[1])"]
                let arr2 = arr1[1].split(separator: "]")
                let derivation = arr2[0]
                dict["prefix"] = "[\(derivation)]"
                dict["fingerprint"] = "\((derivation.split(separator: "/"))[0])"
                let extendedKeyWithPath = arr2[1]
                let arr4 = extendedKeyWithPath.split(separator: "/")
                let extendedKey = arr4[0]
                if extendedKey.contains("tpub") || extendedKey.contains("xpub") {
                    dict["accountXpub"] = "\(extendedKey.replacingOccurrences(of: ")", with: ""))"
                } else if extendedKey.contains("tprv") || extendedKey.contains("xprv") {
                    dict["accountXprv"] = "\(extendedKey.replacingOccurrences(of: ")", with: ""))"
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
                                
                                dict["derivation"] = path
                                
                                switch path {
                                                        
                                case "m/44'/0'/0'", "m/44'/1'/0'":
                                    dict["isBIP44"] = true
                                    dict["isP2PKH"] = true
                                    dict["isAccount"] = true
                                    
                                case "m/84'/0'/0'", "m/84'/1'/0'":
                                    dict["isBIP84"] = true
                                    dict["isP2WPKH"] = true
                                    dict["isAccount"] = true
                                    
                                case "m/49'/0'/0'", "m/49'/1'/0'":
                                    dict["isBIP49"] = true
                                    dict["isP2SHP2WPKH"] = true
                                    dict["isAccount"] = true
                                    
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
            
            if descriptor.contains("combo") {
                
                dict["format"] = "Combo"
                
            } else {
                
                let arr = descriptor.split(separator: "(")
                
                for (i, item) in arr.enumerated() {
                    
                    if i == 0 {
                        
                        switch item {
                            
                        case "wpkh":
                            dict["format"] = "P2WPKH"
                            dict["isP2WPKH"] = true
                            
                        case "sh":
                            if arr[1] == "wpkh" {
                                
                                dict["format"] = "P2SH-P2WPKH"
                                dict["isP2SHP2WPKH"] = true
                                
                            } else {
                                
                                dict["format"] = "P2SH"
                                
                            }
                            
                        case "pk":
                            dict["format"] = "P2PK"
                            
                        case "pkh":
                            dict["format"] = "P2PKH"
                            dict["isP2PKH"] = true
                            
                        default:
                            
                            break
                            
                        }
                    }
                }
                
            }
            
        }
        
        if descriptor.contains("xpub") || descriptor.contains("xprv") {
            dict["chain"] = "Mainnet"
            dict["isHD"] = true
            
        } else if descriptor.contains("tpub") || descriptor.contains("tprv") {
            dict["chain"] = "Testnet"
            dict["isHD"] = true
            
        } else {
            dict["isHD"] = false
            
        }
        
        if descriptor.contains("xprv") || descriptor.contains("tprv") {
            dict["isHot"] = true
            
        } else {
            dict["isHot"] = false
            
        }
        
        return Descriptor(dictionary: dict)
        
    }
    
}
