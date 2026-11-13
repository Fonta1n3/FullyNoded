//
//  WalletImport.swift
//  FullyNoded
//
//  Created by Peter Denton on 10/13/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation
/*{"xpub": "xpub661MyMwAqRbcGkEBKkgQNBH43P6SPriEjzznZfZJTP7WNBb2oYPz5Wbgm3g4ihokSg6pcbJrmhJ2GhE6PozUEoUDK2KPWroV4zHPVtpz5y9", "xfp": "542D0F73", "account": 0,
 
 "bip49": {"xpub": "xpub6DT2pd8Hn46iKqVXW9hJEownWBsaMHpzvW7ZtHZxKjGqS2CBxvzXXv8ZAjRjZumtmhYT2PbmegPkZXwRb1MxhEfe629uEFS8UQqyNmCFsiY", "first": "3KiyBmAfszr2Qxgpia3MWc4ryEHYpcjgVu", "deriv": "m/49'/0'/0'", "xfp": "489C8AED", "name": "p2sh-p2wpkh", "_pub": "ypub6YHJ8HoCvjeCB8geLWUvSu3HgA22HupVqcdnfgTqhjeiV81RDbA69ynhBwPKZpRpBLfFmsCL7LkJSpYzJhmyVUMExMrKpAFck8ucmJCEtnb"},
 
 "bip44": {"xpub": "xpub6BtdppWXMtpt8cQ25MAtKGf3d3kR7SA13pK3C5HLDwhQNm8VohZLPD2z4VQErR2qW4BwUmV2oesbm1HJNTNmrhUf14ZCay4ZcQeuy8HnNTH", "first": "1LNj3Sjo87NsJBTxi8rAFRJ6bAXGHsFF1a", "deriv": "m/44'/0'/0'", "xfp": "FB10EABB", "name": "p2pkh"},
 
 "bip84": {"xpub": "xpub6Bt9P4VShP7Pc3GPVooe256hJeT6z2FcMQ8bDrPt6asmf9VMBUPWps5kaQdyP9b7x1rq14EHqaDTFbAcBprUbGcX6ZtUDWV4K6bEAHZub1r", "first": "bc1qr60r3gcfny68scszm0te5hzmnlx66e2ywu7hym", "deriv": "m/84'/0'/0'", "xfp": "A9B414E2", "name": "p2wpkh", "_pub": "zpub6qYfzPqGzkCMJdedAXNtSFHheajzsGEcBdB2neBerbdXmM7ognie4zQ2cpZ9NxtxmJ6SW1RQktvZ2APjdDgWBjyiqFHKPL82rYiWwXGnKQx"},
 
 "bip48_2": {"xpub": "xpub6FBvsG1d9MpNb8cPCYPm3NxQcSVwKZgtQZwFaxEFD6G6zYUoBs8V55BBQFEp5ox8qDfaQpTcSRhKTp7JCmuKp4Tcvxx1hiZYnnHmTvz3254", "first": null, "deriv": "m/48'/0'/0'/2'", "xfp": "AD06354E", "name": "p2wsh", "_pub": "Zpub75kYbq5u1gThiJ9zovRzHdVDgAq6RAMUZ4dN51HZLsrGivgATaqtQKMPFN7Te4UssxyAnMerExnvMYxBwPtJZ1wVW7TGGwfXDxgvpyVCc36"}, "chain": "BTC",
 
 "bip48_1": {"xpub": "xpub6FBvsG1d9MpNZwwqzk5edotvm4MphayYGcyqRh3SzexMH22yfcMLg9wUZM6ERxoN81Rhf398EG2cFop8ALGxtZTx1QqBzkFwYPrHMVSXDAE", "first": null, "deriv": "m/48'/0'/0'/1'", "xfp": "853B5F64", "name": "p2sh-p2wsh", "_pub": "Ypub6kvHJAQyrzvDqpJLmmLFfyLEepYXrZedW19j8MCskSAdxJR7gfuBPLTYPG1HzJgBm7cVH6joa8mfGG3TBFqvqHGDiDe1z4YRhrBoKymfYZL"}}*/


// MARK: SPECTER
/*
 {"keystore":
 {"ckcc_xpub": "xpub6Bt9P4VShP7Pc3GPVooe256hJeT6z2FcMQ8bDrPt6asmf9VMBUPWps5kaQdyP9b7x1rq14EHqaDTFbAcBprUbGcX6ZtUDWV4K6bEAHZub1r", "xpub": "zpub6qYfzPqGzkCMJdedAXNtSFHheajzsGEcBdB2neBerbdXmM7ognie4zQ2cpZ9NxtxmJ6SW1RQktvZ2APjdDgWBjyiqFHKPL82rYiWwXGnKQx", "label": "Passport (542D0F73)", "ckcc_xfp": 1930374484, "type": "hardware", "hw_type": "passport", "derivation": "m/84'/0'/0'"},
 "wallet_type": "standard", "use_encryption": false, "seed_version": 17}
 */

// MARK: Passport
/*
 {
   "p2sh_deriv": "m/45'",
   "p2sh": "xpubxxx",
   "p2wsh_p2sh_deriv": "m/48'/0'/0'/1'",
   "p2wsh_p2sh": "Ypubxxx",
   "p2wsh_deriv": "m/48'/0'/0'/2'",
   "p2wsh": "Zpubxxx",
   "xfp": "AB88DE89"
 }
 */

// MARK: BlueWallet single sig (Passport, Keystone, Jade "BlueWallet" export)
/*
 {"ExtPubKey": "zpub...", "MasterFingerprint": "73C5DA0A", "AccountKeyPath": "84'/0'/0'"}
 */

public struct WalletImport: CustomStringConvertible {
    
    let bip49:String?
    let bip44:String?
    let bip84:String?
    let bip48:String?
    let bip86:String?
    
    /// Every descriptor found, in the order offered to the user.
    var descriptors: [String] {
        [bip44, bip49, bip84, bip48, bip86].compactMap { $0 }
    }
    
    init(_ dictionary: [String: Any]) {
        var bip44: String?
        var bip49: String?
        var bip84: String?
        var bip48: String?
        var bip86: String?
        
        if let xfp = dictionary["xfp"] as? String,
           ["bip44", "bip49", "bip84", "bip48_2", "bip86"].contains(where: { dictionary[$0] is [String:Any] }) {
            // Coldcard / Passport generic JSON, with any subset of the accounts (a single sig
            // export may carry only one). Each account's own "xfp" is its parent's, not the master's.
            func account(_ key: String, _ defaultPath: String) -> String? {
                guard let account = dictionary[key] as? [String:Any],
                      let xpub = Self.xpub(account["xpub"] as? String) else { return nil }
                let path = Self.origin(account["deriv"] as? String) ?? defaultPath
                return "[\(xfp)/\(path)]\(xpub)/0/*"
            }
            bip44 = account("bip44", "44h/0h/0h").map { "pkh(\($0))" }
            bip49 = account("bip49", "49h/0h/0h").map { "sh(wpkh(\($0)))" }
            bip84 = account("bip84", "84h/0h/0h").map { "wpkh(\($0))" }
            bip48 = account("bip48_2", "48h/0h/0h/2h").map { "wsh(\($0))" }
            bip86 = account("bip86", "86h/0h/0h").map { "tr(\($0))" }
            
        } else if let keystore = dictionary["keystore"] as? [String:Any],
                  let xpub = keystore["ckcc_xpub"] as? String,
                  let label = keystore["label"] as? String {
            
            let arr = label.split(separator: "(")
            if arr.count > 1 {
                let xfp = "\(arr[1])".replacingOccurrences(of: ")", with: "")
                let path = Self.origin(keystore["derivation"] as? String) ?? "84h/0h/0h"
                bip84 = "wpkh([\(xfp)/\(path)]\(xpub)/0/*)"
            }
            
        } else if let xfp = dictionary["xfp"] as? String,
                  let p2wsh_deriv = dictionary["p2wsh_deriv"] as? String,
                  let p2wsh = dictionary["p2wsh"] as? String,
                  let p2wshXpub = XpubConverter.convert(extendedKey: p2wsh) {
            
            let path = Self.origin(p2wsh_deriv) ?? "48h/0h/0h/2h"
            bip48 = "wsh([\(xfp)/\(path)]\(p2wshXpub)/0/*)"
            
        } else if let extendedKey = dictionary["ExtPubKey"] as? String,
                  let xfp = dictionary["MasterFingerprint"] as? String,
                  let path = Self.origin(dictionary["AccountKeyPath"] as? String),
                  let xpub = Self.xpub(extendedKey) {
            
            let key = "[\(xfp.lowercased())/\(path)]\(xpub)/0/*"
            switch path.split(separator: "/").first {
            case "44h": bip44 = "pkh(\(key))"
            case "49h": bip49 = "sh(wpkh(\(key)))"
            case "86h": bip86 = "tr(\(key))"
            case "48h": bip48 = "wsh(\(key))"
            default: bip84 = "wpkh(\(key))"
            }
        }
        
        self.bip44 = bip44
        self.bip49 = bip49
        self.bip84 = bip84
        self.bip48 = bip48
        self.bip86 = bip86
    }
    
    /// "m/84'/0'/0'" → "84h/0h/0h".
    private static func origin(_ path: String?) -> String? {
        guard let path = path?.trimmingCharacters(in: .whitespaces), !path.isEmpty else { return nil }
        let steps = path.split(separator: "/").filter { $0 != "m" }
        guard !steps.isEmpty else { return nil }
        return steps.map { $0.replacingOccurrences(of: "'", with: "h") }.joined(separator: "/")
    }
    
    /// xpub / tpub as is; ypub, zpub, vpub etc. converted.
    private static func xpub(_ key: String?) -> String? {
        guard let key = key else { return nil }
        if key.hasPrefix("xpub") || key.hasPrefix("tpub") { return key }
        return XpubConverter.convert(extendedKey: key)
    }
    
    public var description: String {
        return ""
    }
    
}
