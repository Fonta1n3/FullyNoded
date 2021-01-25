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
    
    static func addressString(_ childKey: HDKey, _ type: AddressType) -> String {
        return childKey.address(type: type).description
    }
    
    static func addressType(_ descriptorStruct: Descriptor) -> AddressType {
        var type:AddressType!
        if descriptorStruct.isP2PKH {
            type = .payToPubKeyHash
        } else if descriptorStruct.isP2WPKH {
            type = .payToWitnessPubKeyHash
        } else if descriptorStruct.isP2SHP2WPKH {
            type = .payToScriptHashPayToWitnessPubKeyHash
        }
        return type
    }
    
    static func addressSignable(_ address: String, _ path: BIP32Path, completion: @escaping ((signable: Bool, signer: String?)) -> Void) {
        CoreDataService.retrieveEntity(entityName: .signers) { signers in
            guard let signers = signers, signers.count > 0 else { return }
            for (i, signer) in signers.enumerated() {
                let signerStruct = SignerStruct(dictionary: signer)
                
                guard let decryptedWords = Crypto.decrypt(signerStruct.words), let words = decryptedWords.utf8 else { return }
                
                var passphrase = ""
                
                if let encryptedPassphrase = signerStruct.passphrase {
                    guard let decryptedPassphrase = Crypto.decrypt(encryptedPassphrase), let pp = decryptedPassphrase.utf8 else { return }
                    
                    passphrase = pp
                }
                
                guard let a = try? Address(string: address) else { return }
                
                var cointype = "0"
                
                if a.network == .testnet {
                    cointype = "1"
                }
                
                guard let mk = masterKey(words: words, coinType: cointype, passphrase: passphrase),
                      let hdKey = try? HDKey(base58: mk),
                      let childKey = try? hdKey.derive(using: path) else { return }
                
                let segwit = childKey.address(type: .payToWitnessPubKeyHash).description
                let wrappedSegwit = childKey.address(type: .payToScriptHashPayToWitnessPubKeyHash).description
                let legacy = childKey.address(type: .payToPubKeyHash).description
                
                if address == segwit || address == wrappedSegwit || address == legacy {
                    completion((true, signerStruct.label))
                    break
                } else {
                    if i + 1 == signers.count {
                        completion((false, nil))
                    }
                }
            }
        }
    }
    
    static func pubkeySignable(_ pubkeys: [PubKey], _ path: BIP32Path, completion: @escaping ((signable: Bool, signer: String?)) -> Void) {
        CoreDataService.retrieveEntity(entityName: .signers) { signers in
            guard let signers = signers, signers.count > 0 else { completion((false, nil)); return }
            
            var canSign = false
            var signerLabel:String?
            
            for (i, signer) in signers.enumerated() {
                let signerStruct = SignerStruct(dictionary: signer)
                
                guard let decryptedWords = Crypto.decrypt(signerStruct.words), let words = decryptedWords.utf8 else { completion((false, nil)); return }
                
                var passphrase = ""
                
                if let encryptedPassphrase = signerStruct.passphrase {
                    guard let decryptedPassphrase = Crypto.decrypt(encryptedPassphrase), let pp = decryptedPassphrase.utf8 else { completion((false, nil)); return }
                    
                    passphrase = pp
                }
                
                guard let mkM = masterKey(words: words, coinType: "0", passphrase: passphrase),
                      let hdKeyM = try? HDKey(base58: mkM),
                      let childKeyM = try? hdKeyM.derive(using: path),
                      let mkT = masterKey(words: words, coinType: "1", passphrase: passphrase),
                      let hdKeyT = try? HDKey(base58: mkT),
                      let childKeyT = try? hdKeyT.derive(using: path) else { completion((false, nil)); return }
                
                for (p, pk) in pubkeys.enumerated() {
                    if childKeyM.pubKey == pk || childKeyT.pubKey == pk {
                        canSign = true
                        signerLabel = signerStruct.label
                    }
                    
                    if i + 1 == signers.count && p + 1 == pubkeys.count {
                        completion((canSign, signerLabel))
                    }
                }
            }
        }
    }
        
    static func verifyAddress(_ address: String, _ path: String, _ descriptor: String, completion: @escaping ((isOurs: Bool, wallet: String?, signable: Bool, signer: String?)) -> Void) {
        CoreDataService.retrieveEntity(entityName: .wallets) { wallets in
            guard let wallets = wallets, wallets.count > 0 else {
                // need to check if signers can sign here
                completion((false, nil, false, nil))
                return
            }
            
            var isOurs = false
            var walletLabel:String?
            var signable = false
            var signer:String?
            
            for (i, wallet) in wallets.enumerated() {
                let walletStruct = Wallet(dictionary: wallet)
                let desc = walletStruct.receiveDescriptor
                let descParser = DescriptorParser()
                let descStr = descParser.descriptor(desc)
                let providedDescStr = descParser.descriptor(descriptor)
                let type = addressType(descStr)
                
                if !providedDescStr.isMulti && path != "no key path" {
                    guard let fullPath = try? BIP32Path(string: path) else { return }
                    
                    addressSignable(address, fullPath) { (isSignable, signerLabel) in
                        if isSignable {
                            signable = true
                        }
                        
                        if signerLabel != nil {
                            signer = signerLabel
                        }
                        
                        if let accountPath = try? fullPath.chop(depth: 3) {
                            if let key = try? HDKey(base58: descStr.accountXpub) {
                                if let childKey = try? key.derive(using: accountPath) {
                                    if addressString(childKey, type) == address {
                                        isOurs = true
                                        walletLabel = walletStruct.label
                                    }
                                }
                            }
                        }
                        
                        if i + 1 == wallets.count {
                            completion((isOurs, walletLabel, signable, signer))
                        }
                    }
                } else if providedDescStr.isMulti && descriptor != "no descriptor" {
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
                                
                                if let derivedAddress = try? Address(scriptPubKey: scriptPubKey, network: network) {
                                    if derivedAddress.description == address {
                                        isOurs = true
                                        walletLabel = walletStruct.label
                                    }
                                }
                            }
                        }
                    }
                    
                    if i + 1 == wallets.count {
                        for (d, derivation) in providedDescStr.derivationArray.enumerated() {
                            guard let fullPath = try? BIP32Path(string: derivation) else { return }
                            
                            var pubkeys = [PubKey]()
                            for (k, key) in providedDescStr.multiSigKeys.enumerated() {
                                guard let hex = Data(hexString: key),
                                      let pubkey1 = try? PubKey(hex, network: .mainnet),
                                      let pubkey2 = try? PubKey(hex, network: .testnet) else { return }
                                pubkeys.append(pubkey1)
                                pubkeys.append(pubkey2)
                                
                                if k + 1 == providedDescStr.multiSigKeys.count {
                                                                
                                    pubkeySignable(pubkeys, fullPath) { (isSignable, signerLabel) in
                                        if isSignable {
                                            signable = true
                                            signer = signerLabel
                                        }
                                        
                                        if d + 1 == providedDescStr.derivationArray.count {
                                            completion((isOurs, walletLabel, signable, signer))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
