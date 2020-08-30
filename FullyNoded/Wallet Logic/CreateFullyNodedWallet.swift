//
//  CreateFullyNodedWallet.swift
//  BitSense
//
//  Created by Peter on 28/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation
import LibWally

enum Keys {
    
    static func donationAddress() -> String? {
        let randomInt = Int.random(in: 0..<10000)
        
        guard let hdKey = HDKey("xpub6C1DcRZo4RfYHE5F4yiA2m26wMBLr33qP4xpVdzY1EkHyUdaxwHhAvAUpohwT4ajjd1N9nt7npHrjd3CLqzgfbEYPknaRW8crT2C9xmAy3G"),
              let path = BIP32Path("0/\(randomInt)"),
              let address = try? hdKey.derive(path).address(.payToWitnessPubKeyHash) else { return nil }
        
        return address.description
    }
    
    static func seed() -> String? {
        var words: String?
        let bytesCount = 16
        var randomBytes = [UInt8](repeating: 0, count: bytesCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytesCount, &randomBytes)
        
        if status == errSecSuccess {
            let data = Data(randomBytes)
            let hex = data.hexString
            if let entropy = BIP39Entropy(hex), let mnemonic = BIP39Mnemonic(entropy) {
                words = mnemonic.description
            }
        }
        
        return words
    }
    
    static func masterKey(words: String, coinType: String, passphrase: String) -> String? {
        let chain: Network
        
        if coinType == "0" {
            chain = .mainnet
        } else {
            chain = .testnet
        }
        
        if let mnmemonic = BIP39Mnemonic(words) {
            let seedHex = mnmemonic.seedHex(passphrase)
            if let mk = HDKey(seedHex, chain), let xpriv = mk.xpriv {
                return xpriv
            }
        }
        
        return nil
    }
    
    static func fingerprint(masterKey: String) -> String? {
        guard let mk = HDKey(masterKey) else { return nil }
        
        return mk.fingerprint.hexString
    }
    
    static func bip84AccountXpub(masterKey: String, coinType: String, account: Int16) -> String? {
        guard let mk = HDKey(masterKey),
              let path = BIP32Path("m/84'/\(coinType)'/\(account)'"),
              let accountKey = try? mk.derive(path) else { return nil }
        
        return accountKey.xpub
    }
    
    static func xpub(path: String, masterKey: String) -> String? {
        guard let mk = HDKey(masterKey),
              let path = BIP32Path(path),
              let accountKey = try? mk.derive(path) else { return nil }
        
        return accountKey.xpub
    }
}
