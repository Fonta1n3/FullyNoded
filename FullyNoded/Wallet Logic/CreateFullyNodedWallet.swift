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
        guard let _ = try? WalletLogic.BDKMnemonic.fromString(mnemonic: words) else {
            return false
        }
        
        return true
    }
    
    static func validPath(_ path: String) -> Bool {
        guard let _ = try? WalletLogic.BDKDerivationPath(path: path) else {
            return false
        }
        
        return true
    }
    
    // [bip84, bip86, segwitCosigner, trCosigner]
    static func descriptorsFromSigner(signer: String, passphrase: String?) -> (
        bip84: String?,
        bip86: String?,
        segwitCosigner: String?,
        taprootCosigner: String?,
        errorMess: String?) {
            let chain = UserDefaults.standard.object(forKey: "chain") as? String ?? "main"
            
            var cointType = "0"
            
            if chain != "main" {
                cointType = "1"
            }
            
            guard let network = WalletLogic.shared.bdkNetwork() else { return (nil, nil, nil, nil, "Can not get BDKNetwork")}
            
            guard let mk = WalletLogic.shared.bdkMasterKey(network: network, mnemonic: signer, passphrase: passphrase ?? "") else {
                return (nil, nil, nil, nil, "Can not get DescriptorSecretKey.")
            }
            
            let xfp = WalletLogic.shared.fingerprint(masterKey: mk)
            
            var coinType: Int = 0
            
            switch network {
            case .testnet, .testnet4, .regtest, .signet:
                coinType = 1
            default:
                break
            }
            
            guard let bip84Path = try? WalletLogic.BDKDerivationPath(path: "m/84h/\(coinType)h/0h") else {
                return (nil, nil, nil, nil, "Can not get BIP84 derivation path.")
            }
            
            guard let segwitBip48Path = try? WalletLogic.BDKDerivationPath(path: "m/48h/\(cointType)h/0h/2h") else {
                return (nil, nil, nil, nil, "Can not get BIP48 segwit path.")
            }
            
            guard let bip86Path = try? WalletLogic.BDKDerivationPath(path: "m/86h/\(coinType)h/0h") else {
                return (nil, nil, nil, nil, "Can not get BIP86 segwit path.")
            }
            
            guard let taprootMultisigBIP48Path = try? WalletLogic.BDKDerivationPath(path: "m/48h/\(coinType)h/0h/3h") else {
                return (nil, nil, nil, nil, "Can not get Taproot MuSig2 path.")
            }
            
            guard let bip84AccountXpub = try? mk.derive(path: bip84Path).asPublic().description.plainXpub else {
                return (nil, nil, nil, nil, "Could not derive bip84 account xpub.")
            }
            
            guard let bip48SegwitAccountXpub = try? mk.derive(path: segwitBip48Path).asPublic().description.plainXpub else {
                return (nil, nil, nil, nil, "Could not derive bip48 account xpub.")
            }
            
            guard let bip86AccountXpub = try? mk.derive(path: bip86Path).asPublic().description.plainXpub else {
                return (nil, nil, nil, nil, "Could not derive bip86 account xpub.")
            }
            
            guard let bip48TaprootMultisigAccountXpub = try? mk.derive(path: taprootMultisigBIP48Path).asPublic().description.plainXpub else {
                return (nil, nil, nil, nil, "Could not derive bip84 account xpub.")
            }
            
            let bip84 = "wpkh([\(xfp)/84h/\(cointType)h/0h]\(bip84AccountXpub)/0/*)"
            let bip86 = "tr([\(xfp)/86h/\(cointType)h/0h]\(bip86AccountXpub)/0/*)"
            let segwitCosigner = "wsh([\(xfp)/48h/\(cointType)h/0h/2h]\(bip48SegwitAccountXpub)/0/*)"
            let trCosigner = "tr([\(xfp)/48h/\(cointType)h/0h/3h]\(bip48TaprootMultisigAccountXpub)/0/*)"
            
            return (bip84, bip86, segwitCosigner, trCosigner, nil)
        }
    
    
    
    static func donationAddress() -> String? {
        let randomInt = Int.random(in: 0..<100)
        
        guard let hdKey = try? HDKey(base58: "xpub6C1DcRZo4RfYHE5F4yiA2m26wMBLr33qP4xpVdzY1EkHyUdaxwHhAvAUpohwT4ajjd1N9nt7npHrjd3CLqzgfbEYPknaRW8crT2C9xmAy3G"),
            let path = try? BIP32Path(string: "0/\(randomInt)"),
              let address = try? hdKey.derive(using: path).address(type: .payToWitnessPubKeyHash) else { return nil }
        
        return address.description
    }
    
    static func childPubkey(xpub: String) -> String? {
        guard let hdKey = try? HDKey(base58: xpub),
            let path = try? BIP32Path(string: "0/0"),
              let pubkey = try? hdKey.derive(using: path).pubKey.data.hex else { return nil }
        
        return pubkey
    }
    
    static func addresses(accountPubkey: String, accountPath: String, completion: @escaping (([[String:Any]]?)) -> Void) {
        var addresses: [[String: Any]] = []
            
        guard let hdKey = try? HDKey(base58: accountPubkey) else {
            completion((nil))
            return
        }
        
        for i in 0...999 {
            guard let path = try? BIP32Path(string: "/0/\(i)") else {
                completion((nil))
                return
            }
            
            guard let address = try? hdKey.derive(using: path).address(type: .payToWitnessPubKeyHash) else {
                completion((nil))
                return
            }
            
            addresses.append(["address": address.description.addressExpanded, "used": false, "balance": 0.0, "derivation": "\(accountPath)/0/\(i)"])
            
            if i + 1 == 999 {
                completion((addresses))
            }
        }
    }
    
    static func seed() -> String? {
        let bytesCount = 32
        var randomBytes = [UInt8](repeating: 0, count: bytesCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytesCount, &randomBytes)
        
        if status == errSecSuccess {
            var data = Crypto.sha256hash(Crypto.sha256hash(Crypto.sha256hash(Data(randomBytes))))
            data = data.subdata(in: Range(0...15))
            return try? WalletLogic.BDKMnemonic.fromEntropy(entropy: data).description
        } else {
            return nil
        }
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
    
    static func bip86AccountXpub(masterKey: String, coinType: String, account: Int16) -> String? {
        guard let hdMasterKey = try? HDKey(base58: masterKey),
            let path = try? BIP32Path(string: "m/86h/\(coinType)h/\(account)h"),
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
    
    static func addressSignable(parentDesc: String, passphrase: String?, completion: @escaping ((signable: Bool, signer: String?)) -> Void) {
        // no path supplied for multisig.
        let fnParentDesc = Descriptor(parentDesc)
        //let parentDescDerivationArray = fnParentDesc.derivationArray
        var signable = false
        var signerLabel: String?
        
        if fnParentDesc.isMulti {
            // its msig, needs special handling
            for (x, derivation) in fnParentDesc.derivationArray.enumerated() {
                guard let accountDerivationPathBDK = try? WalletLogic.BDKDerivationPath(path: derivation) else { return }
                
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
                                //completion((true, signerStruct.label))
                                signerLabel = signerStruct.label
                                signable = true
                            }
                        }
                        
                        if i + 1 == signers.count && x + 1 == fnParentDesc.derivationArray.count {
                            completion((signable, signerLabel))
                        }
                    }
                }
            }
            
        } else {
            //its single sig
            guard let accountDerivationPathBDK = try? WalletLogic.BDKDerivationPath(path: fnParentDesc.derivation) else { return }
            
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
                            //completion((true, signerStruct.label))
                            signerLabel = signerStruct.label
                            signable = true
                        }
                    }
                    
                    if i + 1 == signers.count {
                        completion((signable, signerLabel))
                    }
                }
            }
        }
    }
        
    static func verifyAddress(parentDesc: String,
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
                addressSignable(parentDesc: parentDesc, passphrase: passphrase) { (isSignable, signerLabel) in
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
                    
                    if i + 1 == wallets.count {
                        addressSignable(parentDesc: parentDesc, passphrase: passphrase) { (isSignable, signerLabel) in
                            if isSignable {
                                signable = true
                            }
                            
                            if signerLabel != nil {
                                signer = signerLabel
                            }
                            
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

extension String {
    var plainXpub: String {
        let derivedKeyArr = self.components(separatedBy: "]")
        let derivedKeyArr2 = derivedKeyArr[1].components(separatedBy: "/")
        return "\(derivedKeyArr2[0])"
    }
}
