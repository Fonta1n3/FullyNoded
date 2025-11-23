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
    
    // Used for encrypting JM comms
    static func randomPrivKey() -> Data? {
        guard let seed = Keys.seed(),
              let mk = Keys.masterKey(words: seed, coinType: "0", passphrase: ""),
              let hdkey = try? HDKey(base58: mk) else { return nil }
        
        return hdkey.privKey?.data
    }
    
    static func privKeyToPubKey(_ privKey: Data) -> String? {
        guard let key = try? Key(privKey, network: .mainnet) else { return nil }
        
        return key.pubKey.data.hexString
    }
    
    static func privKey(_ path: String, _ pubkey: String, completion: @escaping ((privKey: Data?, errorMessage: String?)) -> Void) {
        guard let bip32Path = try? BIP32Path(string: path) else {
            completion((nil, "Invalid bip32 path."))
            return
        }
        
        CoreDataService.retrieveEntity(entityName: .signers) { encryptedSigners in
            guard let encryptedSigners = encryptedSigners, encryptedSigners.count > 0 else {
                completion((nil, "No signers. This feature only works with hot wallets for now."))
                return
            }
            
            for (i, encryptedSigner) in encryptedSigners.enumerated() {
                let encryptedSignerStruct = SignerStruct(dictionary: encryptedSigner)
                
                guard let encryptedWords = encryptedSignerStruct.words,
                        let wordsData = Crypto.decrypt(encryptedWords),
                        let words = wordsData.utf8String else {
                    completion((nil, "Unable to decrypt your signer."))
                    return
                }
                
                var passphrase = ""
                
                if let encryptedPassphrase = encryptedSignerStruct.passphrase {
                    guard let decryptedPassphrase = Crypto.decrypt(encryptedPassphrase),
                            let passphraseString = decryptedPassphrase.utf8String else {
                        completion((nil, "Unable to decrypt your passphrase."))
                        return
                    }
                    
                    passphrase = passphraseString
                }
                
                var coinType = "0"
                
                if let chain = UserDefaults.standard.object(forKey: "chain") as? String {
                    if chain != "main" {
                        coinType = "1"
                    }
                }
                
                guard let masterKey = Keys.masterKey(words: words, coinType: coinType, passphrase: passphrase) else {
                    completion((nil, "Unable to derive your signers master key."))
                    return
                }
                
                guard let hdkey = try? HDKey(base58: masterKey),
                        let derivedKey = try? hdkey.derive(using: bip32Path) else {
                    completion((nil, "Unable to derive key from your master key."))
                    return
                }
                
                if derivedKey.pubKey.data.hex == pubkey {
                    guard let privKey = derivedKey.privKey?.data else {
                        completion((nil, "Unable to convert the key to a private key."))
                        return
                    }
                    
                    completion((privKey, nil))
                    break
                    
                } else if i + 1 == encryptedSigner.count {
                    completion((nil, "Looks like none of your signers can sign for that utxo. This feature only works with hot wallets for now."))
                }
            }
        }
    }
    
    static func validMnemonic(_ words: String) -> Bool {
        guard let _ = try? BIP39Mnemonic(words: words) else { return false }
        
        return true
    }
    
    static func validPath(_ path: String) -> Bool {
        guard let _ = try? BIP32Path(string: path) else { return false }
        
        return true
    }
    
    static func dataToSigner(_ data: Data) -> String? {
        return try? BIP39Mnemonic(entropy: BIP39Mnemonic.Entropy(data)).words.joined(separator: " ")
    }
    
    static func wordsToEntropy(_ words: String) -> BIP39Mnemonic.Entropy? {
        return try? BIP39Mnemonic(words: words).entropy
    }
    
    static func descriptorsFromSigner(signer: String, passphrase: String?) -> (descriptors: [String]?, errorMess: String?) {
        let chain = UserDefaults.standard.object(forKey: "chain") as? String ?? "main"
        
        var cointType = "0"
        
        if chain != "main" {
            cointType = "1"
        }
        
        guard let mk = Keys.masterKey(words: signer, coinType: cointType, passphrase: passphrase ?? ""),
              let xfp = Keys.fingerprint(masterKey: mk),
              let bip84Xpub = Keys.bip84AccountXpub(masterKey: mk, coinType: cointType, account: 0),
              let bip48Xpub = Keys.xpub(path: "m/48h/\(cointType)h/0h/2h", masterKey: mk) else {
            return (nil, "Error deriving descriptors.")
        }
        
        let cosigner = "wsh([\(xfp)/48h/\(cointType)h/0h/2h]\(bip48Xpub)/0/*)"
        let bip84 = "wpkh([\(xfp)/84h/\(cointType)h/0h]\(bip84Xpub)/0/*)"
        
        return ([bip84, cosigner], nil)
    }
    
    static func donationAddress() -> String? {
        let randomInt = Int.random(in: 0..<100)
        
        guard let hdKey = try? HDKey(base58: "xpub6C1DcRZo4RfYHE5F4yiA2m26wMBLr33qP4xpVdzY1EkHyUdaxwHhAvAUpohwT4ajjd1N9nt7npHrjd3CLqzgfbEYPknaRW8crT2C9xmAy3G"),
            let path = try? BIP32Path(string: "0/\(randomInt)"),
              let address = try? hdKey.derive(using: path).address(type: .payToWitnessPubKeyHash) else { return nil }
        
        return address.description
    }
    
    static func seed() -> String? {
        var words: String?
        let bytesCount = 32
        var randomBytes = [UInt8](repeating: 0, count: bytesCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytesCount, &randomBytes)
        
        if status == errSecSuccess {
            var data = Crypto.sha256hash(Crypto.sha256hash(Crypto.sha256hash(Data(randomBytes))))
            data = data.subdata(in: Range(0...15))
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
            let path = try? BIP32Path(string: "m/84h/\(coinType)h/\(account)h"),
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
    
    static func xprv(path: String, masterKey: String) -> String? {
        if path == "m" {
            return try? HDKey(base58: masterKey).xpriv
        } else {
            guard let hdMasterKey = try? HDKey(base58: masterKey),
                let path = try? BIP32Path(string: path),
                let accountKey = try? hdMasterKey.derive(using: path) else { return nil }
            
            return accountKey.xpriv
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
    
    static func addressType(_ descriptorStruct: Descriptor) -> AddressType? {
        var type:AddressType?
        if descriptorStruct.isP2PKH {
            type = .payToPubKeyHash
            // Libwally does not directly support Taproot for now so using this hack.
        } else if descriptorStruct.isP2WPKH || descriptorStruct.isP2TR {
            type = .payToWitnessPubKeyHash
        } else if descriptorStruct.isP2SHP2WPKH {
            type = .payToScriptHashPayToWitnessPubKeyHash
        }
        return type
    }
    
    static func addressSignable(_ parentDesc: String, _ path: String, _ passphrase: String?, completion: @escaping ((signable: Bool, signer: String?)) -> Void) {
        let pathArr = path.split(separator: "/")
        
        guard pathArr.count == 6 else {
            // Non standard path, you are on your own.
            #if DEBUG
            print("non standard path")
            #endif
            completion((false, nil))
            return
        }
        
        let accountKeyPath = "m/\(pathArr[1])/\(pathArr[2])/\(pathArr[3])"
        
        guard let accountDerivationPathBDK = try? WalletLogic.BDKDerivationPath(path: accountKeyPath) else { return }
                
        CoreDataService.retrieveEntity(entityName: .signers) { signers in
            guard let signers = signers, signers.count > 0 else { completion((false, nil)); return }
            
            for (i, signer) in signers.enumerated() {
                let signerStruct = SignerStruct(dictionary: signer)
                
                if var encryptedWords = signerStruct.words,
                   var decryptedWords = Crypto.decrypt(encryptedWords),
                   var words = decryptedWords.utf8String {
                    
                    var passphrase = ""
                    var encryptedPassphrase: Data = "".utf8
                    
                    defer {
                        encryptedWords.secureZero()
                        decryptedWords.secureZero()
                        words.secureWipe()
                        encryptedPassphrase.secureZero()
                        passphrase.secureWipe()
                    }
                                        
                    guard let network = WalletLogic.shared.bdkNetwork() else { return }
                                        
                    guard let bdkMasterKey = WalletLogic.shared.bdkMasterKey(network: network, mnemonic: words, passphrase: passphrase) else { return }
                    
                    guard let derivedAccountKey = try? bdkMasterKey.derive(path: accountDerivationPathBDK) else { return }
                                        
                    // The prefix doesn't matter here we just want the damn xpub.
                    let derivedAccountXpubDesc = "wpkh(\(derivedAccountKey.asPublic().description))"
                    let plainXpub = Descriptor(derivedAccountXpubDesc).accountXpub
                                        
                    if parentDesc.contains(plainXpub) {
                        completion((true, signerStruct.label))
                    }
                } else if i + 1 == signers.count {
                    completion((false, nil))
                }
            }
        }
    }
        
    static func verifyAddress(parentDesc: String,
                              path: String,
                              passphrase: String?,
                              completion: @escaping ((isOurs: Bool,
                                                      wallet: String?,
                                                      signable: Bool,
                                                      signer: String?)) -> Void) {
        
        var isOurs = false
        var walletLabel: String?
        var signable = false
        var signer: String?
        
        CoreDataService.retrieveEntity(entityName: .wallets) { wallets in
            guard let wallets = wallets, wallets.count > 0 else {
                addressSignable(parentDesc, path, passphrase) { (isSignable, signerLabel) in
                    if isSignable {
                        signable = true
                    }
                    
                    if signerLabel != nil {
                        signer = signerLabel
                    }
                    
                    completion((false, nil, signable, signer))
                }
                
                return
            }
            
            for (i, wallet) in wallets.enumerated() {
                if wallet["id"] != nil {
                    let localWalletStruct = Wallet(dictionary: wallet)
                    let localWalletRecDesc = localWalletStruct.receiveDescriptor
                    let localWalletChangeDesc = localWalletStruct.changeDescriptor
                    let outputParentDescStr = Descriptor(parentDesc)
                    
                    #if DEBUG
                    print("localWalletRecDesc: \(localWalletRecDesc)")
                    print("localWalletChangeDesc: \(localWalletChangeDesc)")
                    print("outputParentDescStr: \(outputParentDescStr.string)")
                    #endif
                    
                    if localWalletRecDesc == outputParentDescStr.string || localWalletChangeDesc == outputParentDescStr.string {
                        isOurs = true
                        walletLabel = localWalletStruct.label
                    }
                    
                    addressSignable(parentDesc, path, passphrase) { (isSignable, signerLabel) in
                        if isSignable {
                            signable = true
                        }
                        
                        if signerLabel != nil {
                            signer = signerLabel
                        }
                        
                        if i + 1 == wallets.count {
                            completion((isOurs, walletLabel, signable, signer))
                        }
                    }
                } else if i + 1 == wallets.count {
                    // TODO: DELETE GHOST WALLET
                    print("bad luck...")
                }
            }
        }
    }
}
