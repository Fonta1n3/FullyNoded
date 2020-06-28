//
//  CreateFullyNodedWallet.swift
//  BitSense
//
//  Created by Peter on 28/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation
import LibWally

class CreateFullyNodedWallet {
    
    class func seed() -> String? {
        var words:String?
        let bytesCount = 16
        var randomBytes = [UInt8](repeating: 0, count: bytesCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytesCount, &randomBytes)
        if status == errSecSuccess {
            let data = Data(randomBytes)
            let hex = data.hexString
            if let entropy = BIP39Entropy(hex) {
                if let mnemonic = BIP39Mnemonic.init(entropy) {
                    words = mnemonic.description
                }
            }
        }
        return words
    }
    
    class func masterKey(words: String) -> String? {
        var masterKey:String?
        if let mnmemonic = BIP39Mnemonic(words) {
            let seedHex = mnmemonic.seedHex("")
            if let mk = HDKey(seedHex, .testnet) {
                if mk.xpriv != nil {
                    masterKey = mk.xpriv!
                }
            }
        }
        return masterKey
    }
    
    class func fingerpint(masterKey: String) -> String? {
        var fingerprint:String?
        if let mk = HDKey(masterKey) {
            fingerprint = mk.fingerprint.hexString
        }
        return fingerprint
    }
    
    class func bip84AccountXpub(masterKey: String) -> String? {
        var xpub:String?
        if let mk = HDKey(masterKey) {
            if let path = BIP32Path("m/84'/1'/0'") {
                do {
                    let accountKey = try mk.derive(path)
                    xpub = accountKey.xpub
                } catch {
                    
                }
            }
        }
        return xpub
    }
}
