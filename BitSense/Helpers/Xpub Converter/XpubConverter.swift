//
//  XpubConverter.swift
//  BitSense
//
//  Created by Peter on 12/05/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation
import CryptoKit

class XpubConverter {
    
    /// Takes in any extended public key format as per SLIP-0132 and returns a Bitcoin Core compatible xpub or tpub.
    class func convert(extendedKey: String) -> String? {
        let mainnetXpubPrefix = "0488b21e"
        let testnetTpubPrefix = "043587cf"
        let mainnetXprvPrefix = "0488ade4"
        let testnetTprvPrefix = "04358394"
        var providedPrefix = ""
        var returnedPrefix = mainnetXpubPrefix
        let possibleXpubPrefixes = [
            /// Pubkeys
            "ypub": "049d7cb2",/// Mainnet
            "Ypub": "0295b43f",
            "zpub": "04b24746",
            "Zpub": "02aa7ed3",
            "upub": "044a5262",/// Testnet
            "Upub": "024289ef",
            "vpub": "045f1cf6",
            "Vpub": "02575483",
            ///Privkeys
            "yprv": "049d7878",/// Mainnet
            "zprv": "04b2430c",
            "Yprv": "0295b005",
            "Zprv": "02aa7a99",
            "uprv": "044a4e28",/// Testnet
            "vprv": "045f18bc",
            "Uprv": "024285b5",
            "Vprv": "02575048"
        ]
        
        for (key, value) in possibleXpubPrefixes {
            
            if extendedKey.hasPrefix(key) {
                providedPrefix = value
                
            }
        }
        
        switch providedPrefix {
        case "044a5262", "024289ef", "045f1cf6", "02575483":
            returnedPrefix = testnetTpubPrefix
            
        case "044a4e28", "045f18bc", "024285b5", "02575048":
            returnedPrefix = testnetTprvPrefix

        case "049d7878", "04b2430c", "0295b005", "02aa7a99":
            returnedPrefix = mainnetXprvPrefix
            
        default:
            break
        }
        
        if providedPrefix != "" {
            /// Decodes our original extended key to base58 data.
            var b58 = Base58.decode(extendedKey)
            /// Removes the original prefix.
            b58.removeFirst(4)
            /// Converts the new prefix string to data.
            var prefix = Data.init(hex: returnedPrefix)
            /// Appends the xpub data to the new prefix.
            prefix.append(contentsOf: b58)
            /// Converts our data to array so we can easily manipulate it.
            var convertedXpub = [UInt8](prefix)
            /// Removes incorrect checksum.
            convertedXpub.removeLast(4)
            /// Hashes the new raw xpub twice.
            let hash = SHA256.hash(data: Data(SHA256.hash(data: convertedXpub)))
            /// Gets the correct checksum from the double hash.
            let checksum = Data(hash).subdata(in: Range(0...3))
            /// Appends it.
            convertedXpub.append(contentsOf: checksum)
            /// And its ready 🤩
            return Base58.encode(convertedXpub)
            
        } else {
            /// Invalid extended key supplied by the user.
            return nil
            
        }
    }
}
