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
    
    static func validMnemonic(_ words: String) -> Bool {
        guard let _ = try? BIP39Mnemonic(words: words) else { return false }
        
        return true
    }
    
    static func vaildPath(_ path: String) -> Bool {
        guard let _ = try? BIP32Path(string: path) else { return false }
        
        return true
    }
    
    static func donationAddress() -> String? {
        let randomInt = Int.random(in: 0..<99999)
        
        guard let hdKey = try? HDKey(base58: "xpub6C1DcRZo4RfYHE5F4yiA2m26wMBLr33qP4xpVdzY1EkHyUdaxwHhAvAUpohwT4ajjd1N9nt7npHrjd3CLqzgfbEYPknaRW8crT2C9xmAy3G"),
            let path = try? BIP32Path(string: "0/\(randomInt)"),
            let address = try? hdKey.derive(using: path).address(type: .payToWitnessPubKeyHash) else { return nil }
        
        return address.description
    }
    
    static func seed() -> String? {
        var words: String?
        let bytesCount = 16
        var randomBytes = [UInt8](repeating: 0, count: bytesCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytesCount, &randomBytes)
        
        if status == errSecSuccess {
            let data = Data(randomBytes)
            let entropy = BIP39Mnemonic.Entropy(data)
            if let mnemonic = try? BIP39Mnemonic(entropy: entropy) {
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
        
        if let mnmemonic = try? BIP39Mnemonic(words: words) {
            let seedHex = mnmemonic.seedHex(passphrase: passphrase)
            if let hdMasterKey = try? HDKey(seed: seedHex, network: chain), let xpriv = hdMasterKey.xpriv {
                return xpriv
            }
        }
        
        return nil
    }
    
    static func fingerprint(masterKey: String) -> String? {
        guard let hdMasterKey = try? HDKey(base58: masterKey) else { return nil }
        
        return hdMasterKey.fingerprint.hexString
    }
    
    static func bip84AccountXpub(masterKey: String, coinType: String, account: Int16) -> String? {
        guard let hdMasterKey = try? HDKey(base58: masterKey),
            let path = try? BIP32Path(string: "m/84'/\(coinType)'/\(account)'"),
            let accountKey = try? hdMasterKey.derive(using: path) else { return nil }
        
        return accountKey.xpub
    }
    
    static func xpub(path: String, masterKey: String) -> String? {
        if path == "m" {
            return try? HDKey(base58: masterKey).xpub
        } else {
            guard let hdMasterKey = try? HDKey(base58: masterKey),
                let path = try? BIP32Path(string: path),
                let accountKey = try? hdMasterKey.derive(using: path) else { return nil }
            
            return accountKey.xpub
        }
    }
    
    static func validPsbt(_ psbt: String) -> Bool {
        guard let _ = try? PSBT(psbt: psbt, network: .mainnet) else {
            
            guard let _ = try? PSBT(psbt: psbt, network: .testnet) else {
                return false
            }
            
            return true
        }
        
        return true
    }
    
    static func validTx(_ tx: String) -> Bool {
        guard let _ = try? Transaction(hex: tx) else {
            return false
        }
        
        return true
    }
    
    static func verifyAddress(_ address: String, _ path: String, _ descriptor: String, completion: @escaping ((isOurs: Bool, wallet: String?)) -> Void) {
        CoreDataService.retrieveEntity(entityName: .wallets) { wallets in
            guard let wallets = wallets, wallets.count > 0 else { completion((false, nil)); return }
            
            var isOurs = false
            var walletLabel:String?
            
            for (i, wallet) in wallets.enumerated() {
                let walletStruct = Wallet(dictionary: wallet)
                let desc = walletStruct.receiveDescriptor
                let descParser = DescriptorParser()
                let descStr = descParser.descriptor(desc)
                let providedDescStr = descParser.descriptor(descriptor)
                if !providedDescStr.isMulti {
                    if let fullPath = try? BIP32Path(string: path) {
                        if let accountPath = try? fullPath.chop(depth: 3) {
                            if let key = try? HDKey(base58: descStr.accountXpub) {
                                if let childKey = try? key.derive(using: accountPath) {
                                    var type:AddressType!
                                    if descStr.isP2PKH {
                                        type = .payToPubKeyHash
                                    } else if descStr.isP2WPKH {
                                        type = .payToWitnessPubKeyHash
                                    } else if descStr.isP2SHP2WPKH {
                                        type = .payToScriptHashPayToWitnessPubKeyHash
                                    }
                                    let derivedAddress = childKey.address(type: type).description
                                    if derivedAddress == address {
                                        isOurs = true
                                        walletLabel = walletStruct.label
                                    }
                                }
                            }
                        }
                    }
                } else {
                    var keys = [PubKey]()
                    var network:Network!
                    
                    if providedDescStr.derivationArray.count == descStr.multiSigKeys.count {
                        for (x, xpub) in descStr.multiSigKeys.enumerated() {
                            guard let fullPath = try? BIP32Path(string: providedDescStr.derivationArray[x]),
                                  let accountPath = try? fullPath.chop(depth: 4),
                                  let key = try? HDKey(base58: xpub) else { return }
                            
                            network = key.network
                            
                            guard let childKey = try? key.derive(using: accountPath) else { return }
                            
                            keys.append(childKey.pubKey)
                            
                            if x + 1 == descStr.multiSigKeys.count {
                                let scriptPubKey = ScriptPubKey(multisig: keys, threshold: UInt(descStr.sigsRequired), isBIP67: descStr.isBIP67)
                                
                                guard let derivedAddress = try? Address(scriptPubKey: scriptPubKey, network: network) else { return }
                                
                                if derivedAddress.description == address {
                                    isOurs = true
                                    walletLabel = walletStruct.label
                                }
                            }
                        }
                    }
                }
                if i + 1 == wallets.count {
                    completion((isOurs, walletLabel))
                }
            }
        }
    }
}
