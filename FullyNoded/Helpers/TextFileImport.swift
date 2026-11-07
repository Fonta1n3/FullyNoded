//
//  TextFileImport.swift
//  FullyNoded
//
//  Created by Peter Denton on 10/17/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

class TextFileImport {
    class func parse(_ txt: String) -> (accountMap: [String:Any]?, errMessage: String?) {        
        let myStrings = txt.components(separatedBy: .newlines)
        var name = ""
        var sigsRequired = ""
        var deriv = ""
        var keys = [String]()
        var descriptor = ""
        var errorMessage:String?
        var format = ""
        
        for item in myStrings {
            if item.contains("Name: ") {
                name = item.replacingOccurrences(of: "Name: ", with: "")
            } else if item.contains("Policy: ") {
                let policy = item.replacingOccurrences(of: "Policy: ", with: "")
                let arr = policy.split(separator: " ")
                sigsRequired = "\(arr[0])"
            } else if item.contains("Format: ") {
                format = item.replacingOccurrences(of: "Format: ", with: "").condenseWhitespace().uppercased()
            } else if item.contains("Derivation: ") {
                deriv = item.replacingOccurrences(of: "Derivation: ", with: "")
            } else if item.hasPrefix("seed: ") && !item.hasPrefix("#") {
                keys.append(item)
            } else if !item.hasPrefix("#") {
                var processed = item.condenseWhitespace()
                processed = processed.replacingOccurrences(of: "\n", with: "")
                if processed != "" {
                    keys.append(processed.replacingOccurrences(of: " ", with: ""))
                }
            }
        }
        
        // Single sig (as Fully Noded's own wallet export writes it): "Policy: Single Sig",
        // "Format: P2WPKH" and one "xfp:xpub" line.
        let singleSigScripts = ["P2WPKH": ("wpkh(", ")"), "P2SH-P2WPKH": ("sh(wpkh(", "))"), "P2PKH": ("pkh(", ")"), "P2TR": ("tr(", ")")]
        if let (open, close) = singleSigScripts[format] {
            guard keys.count == 1 else {
                return (nil, "A single sig wallet file should hold exactly one key.")
            }
            let arr = keys[0].split(separator: ":")
            guard arr.count == 2, !deriv.isEmpty else {
                return (nil, "This does not seem to be a supported import type. Please let us know about it so we can add support.")
            }
            var xpub = "\(arr[1])"
            if !xpub.hasPrefix("xpub") && !xpub.hasPrefix("tpub") {
                guard let converted = XpubConverter.convert(extendedKey: xpub) else {
                    return (nil, "There was a problem converting your extended key to an xpub.")
                }
                xpub = converted
            }
            let path = deriv.replacingOccurrences(of: "m/", with: "")
            return (["descriptor": "\(open)[\(arr[0])/\(path)]\(xpub)/0/*\(close)", "blockheight": Int64(0), "watching": [], "label": name] as [String : Any], nil)
        }
        
        guard format.isEmpty || format == "P2WSH" else {
            return (nil, "Unsupported policy. Currently we only support p2wsh multisig and single sig imports.")
        }
        
        descriptor = "wsh(sortedmulti(\(sigsRequired),"
        
        for (i, key) in keys.enumerated() {
            
            func addKey(_ xpub: String, _ xfp: String) {
                if !xpub.hasPrefix("xpub") && !xpub.hasPrefix("tpub") {
                    guard let extKey = XpubConverter.convert(extendedKey: xpub) else {
                        errorMessage = "There was a problem converting your extended key to an xpub."
                        return
                    }
                    
                    descriptor += "[\(xfp)/\(deriv.replacingOccurrences(of: "m/", with: ""))]\(extKey)/0/*"
                } else {
                    descriptor += "[\(xfp)/\(deriv.replacingOccurrences(of: "m/", with: ""))]\(xpub)/0/*"
                }
                
                if i < keys.count - 1 {
                    descriptor += ","
                } else {
                    descriptor += "))"
                }
            }
            
            if key.hasPrefix("seed: ") {
                let words = key.replacingOccurrences(of: "seed: ", with: "")
                
                guard let encryptedData = Crypto.encrypt(words.utf8) else {
                    return (nil, "Unable to encrypt the seed words... Please let us know about this bug.")
                }
                
                saveSigner(encryptedSigner: encryptedData) { saved in
                    guard saved else {
                        errorMessage = "Unable to save the encrypted signer... Please let us know about this bug."
                        return
                    }
                }
                
                var coinType = "0"
                
                let chain = UserDefaults.standard.object(forKey: "chain") as? String ?? "main"
                
                if chain != "main" {
                    coinType = "1"
                }
                
                guard let mk = Keys.masterKey(words: words, coinType: coinType, passphrase: "") else {
                    return (nil, "Unable to derive the master key from the seed words... Please let us know about this bug.")
                }
                
                guard let xfp = Keys.fingerprint(masterKey: mk) else {
                    return (nil, "Unable to derive the fingerprint from the master key... Please let us know about this bug.")
                }
                
                guard let xpub = Keys.xpub(path: "m/48h/\(coinType)h/0h/2h", masterKey: mk) else {
                    return (nil, "Unable to derive the bip48 xpub from the master key... Please let us know about this bug.")
                }
                
                addKey(xpub, xfp)
                
            } else {
                let arr = key.split(separator: ":")
                let xfp = "\(arr[0])"
                
                guard arr.count > 1 else {
                    return (nil, "This does not seem to be a supported import type. Please let us know about it so we can add support.")
                }
                
                let xpub = "\(arr[1])"
                addKey(xpub, xfp)
            }
        }
        
        return (["descriptor": descriptor, "blockheight": Int64(0), "watching": [], "label": name] as [String : Any], errorMessage)
    }
    
    /// A text file holding one descriptor among comments and blank lines (as Sparrow and Coldcard
    /// export them) → that descriptor.
    class func singleDescriptor(in text: String) -> String? {
        let allLines = text.components(separatedBy: .newlines)
        let lines = allLines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        guard lines.count == 1, lines.count < allLines.count else { return nil }
        let line = lines[0]
        let scripts = ["wpkh(", "sh(", "pkh(", "wsh(", "tr(", "combo(", "addr(", "multi(", "sortedmulti("]
        return scripts.contains(where: { line.lowercased().hasPrefix($0) }) ? line : nil
    }
    
    class func saveSigner(encryptedSigner: Data, completion: @escaping ((Bool)) -> Void) {
        let dict = ["id":UUID(), "words":encryptedSigner, "added": Date()] as [String:Any]
        CoreDataService.saveEntity(dict: dict, entityName: .signers) { success in
            completion(success)
        }
    }
}
