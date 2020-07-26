//
//  CreateFullyNodedWallet.swift
//  BitSense
//
//  Created by Peter on 28/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation
import LibWally

class Keys {
    
    class func donationAddress() -> String? {
        let randomInt = Int.random(in: 0..<10000)
        if let hdKey = HDKey("xpub6C1DcRZo4RfYHE5F4yiA2m26wMBLr33qP4xpVdzY1EkHyUdaxwHhAvAUpohwT4ajjd1N9nt7npHrjd3CLqzgfbEYPknaRW8crT2C9xmAy3G") {
            if let path = BIP32Path("0/\(randomInt)") {
                do {
                    let address = try hdKey.derive(path).address(.payToWitnessPubKeyHash)
                    return address.description
                } catch {
                   return nil
                }
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
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
    
    class func masterKey(words: String, coinType: String, passphrase: String) -> String? {
        var chain:Network!
        if coinType == "0" {
            chain = .mainnet
        } else {
            chain = .testnet
        }
        var masterKey:String?
        if let mnmemonic = BIP39Mnemonic(words) {
            let seedHex = mnmemonic.seedHex(passphrase)
            if let mk = HDKey(seedHex, chain) {
                if mk.xpriv != nil {
                    masterKey = mk.xpriv!
                }
            }
        }
        return masterKey
    }
    
    class func fingerprint(masterKey: String) -> String? {
        var fingerprint:String?
        if let mk = HDKey(masterKey) {
            fingerprint = mk.fingerprint.hexString
        }
        return fingerprint
    }
    
    class func bip84AccountXpub(masterKey: String, coinType: String, account: Int16) -> String? {
        var xpub:String?
        if let mk = HDKey(masterKey) {
            if let path = BIP32Path("m/84'/\(coinType)'/\(account)'") {
                do {
                    let accountKey = try mk.derive(path)
                    xpub = accountKey.xpub
                } catch {
                    
                }
            }
        }
        return xpub
    }
    
    class func xpub(path: String, masterKey: String) -> String? {
        var xpub:String?
        if let mk = HDKey(masterKey) {
            if let path = BIP32Path(path) {
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
