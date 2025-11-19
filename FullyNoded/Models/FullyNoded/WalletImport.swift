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

public struct WalletImport: CustomStringConvertible {
    
    let bip49:String?
    let bip44:String?
    let bip84:String?
    let bip48:String?
    let bip86:String?
    
    init(_ dictionary: [String: Any]) {
        
        if let xfp = dictionary["xfp"] as? String,
           let bip49Dict = dictionary["bip49"] as? [String:Any],
           let bip44Dict = dictionary["bip44"] as? [String:Any],
           let bip84Dict = dictionary["bip84"] as? [String:Any],
           let bip48Dict = dictionary["bip48_2"] as? [String:Any],
           let bip49Xpub = bip49Dict["xpub"] as? String,
           let bip44Xpub = bip44Dict["xpub"] as? String,
           let bip84Xpub = bip84Dict["xpub"] as? String,
           let bip48Xpub = bip48Dict["xpub"] as? String {
            
            bip49 = "sh(wpkh([\(xfp)/49h/0h/0h]\(bip49Xpub)/0/*))"
            bip44 =  "pkh([\(xfp)/44h/0h/0h]\(bip44Xpub)/0/*)"
            bip84 = "wpkh([\(xfp)/84h/0h/0h]\(bip84Xpub)/0/*)"
            bip48 = "wsh([\(xfp)/48h/0h/0h/2h]\(bip48Xpub)/0/*)"
            
            if let bip86Dict = dictionary["bip86"] as? [String:Any],
                let bip86Xpub = bip86Dict["xpub"] as? String {
                bip86 = "tr([\(xfp)/86h/0h/0h]\(bip86Xpub)/0/*)"
            } else {
                bip86 = nil
            }
            
        } else if let keystore = dictionary["keystore"] as? [String:Any],
                  let xpub = keystore["ckcc_xpub"] as? String,
                  let label = keystore["label"] as? String {
            
            let arr = label.split(separator: "(")
            let xfp = "\(arr[1])".replacingOccurrences(of: ")", with: "")
            bip84 = "wpkh([\(xfp)/84h/0h/0h]\(xpub)/0/*)"
            bip49 = nil
            bip44 = nil
            bip48 = nil
            bip86 = nil
            
        } else if let xfp = dictionary["xfp"] as? String,
                    let p2wsh_deriv = dictionary["p2wsh_deriv"] as? String,
                    let p2wsh = dictionary["p2wsh"] as? String,
                  let p2wshXpub = XpubConverter.convert(extendedKey: p2wsh) {
            
            bip48 = "wsh([\(xfp)/48h/0h/0h/2h]\(p2wshXpub)/0/*)"
            bip49 = nil
            bip44 = nil
            bip84 = nil
            bip86 = nil
            
        } else {
            bip49 = nil
            bip44 = nil
            bip84 = nil
            bip48 = nil
            bip86 = nil
        }
    }
    
    public var description: String {
        return ""
    }
    
}
