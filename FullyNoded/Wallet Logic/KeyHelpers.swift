//
//  CreateFullyNodedWallet.swift
//  BitSense
//
//  Created by F on 28/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation
import BitcoinDevKit
import P256K

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
    
    
    
    // MARK: - Extended keys (BitcoinDevKit)

    /// A random receive address (0/0…0/99) of the donation xpub.
    static func donationAddress() -> String? {
        let randomInt = Int.random(in: 0..<100)
        let xpub = "xpub6C1DcRZo4RfYHE5F4yiA2m26wMBLr33qP4xpVdzY1EkHyUdaxwHhAvAUpohwT4ajjd1N9nt7npHrjd3CLqzgfbEYPknaRW8crT2C9xmAy3G"

        guard let descriptor = try? WalletLogic.BDKDescriptor(descriptor: "wpkh(\(xpub)/0/*)", networkKind: .main),
              let address = try? descriptor.deriveAddress(index: UInt32(randomInt), network: .bitcoin) else { return nil }

        return address.description
    }

    /// Compressed public key (hex) of child 0/0 of `xpub` (xpub or tpub).
    static func childPubkey(xpub: String) -> String? {
        guard let key = try? DescriptorPublicKey.fromString(publicKey: xpub),
              let path = try? WalletLogic.BDKDerivationPath(path: "m/0/0"),
              let child = try? key.derive(path: path) else { return nil }

        return extendedKeyPayload(plainExtendedKey(child.description))?.key.hexString
    }

    static func seedWords() -> String? {
        guard let entropy = Crypto.secret() else { return nil }
        
        return try? WalletLogic.BDKMnemonic.fromEntropy(entropy: entropy).description
    }

    /// Master extended private key (xprv for coin type "0", tprv otherwise) of a BIP39
    /// mnemonic and passphrase.
    static func masterKey(words: String, coinType: String, passphrase: String) -> String? {
        guard let mnemonic = try? WalletLogic.BDKMnemonic.fromString(mnemonic: words) else { return nil }

        let master = DescriptorSecretKey(networkKind: coinType == "0" ? .main : .test,
                                         mnemonic: mnemonic,
                                         password: passphrase.isEmpty ? nil : passphrase)
        return plainExtendedKey(master.description)
    }

    /// Master key fingerprint (8 lowercase hex characters) of an extended private key.
    static func fingerprint(masterKey: String) -> String? {
        guard let key = try? DescriptorSecretKey.fromString(privateKey: masterKey) else { return nil }

        return key.asPublic().masterFingerprint()
    }

    static func bip84AccountXpub(masterKey: String, coinType: String, account: Int16) -> String? {
        return xpub(path: "m/84h/\(coinType)h/\(account)h", masterKey: masterKey)
    }

    static func bip86AccountXpub(masterKey: String, coinType: String, account: Int16) -> String? {
        return xpub(path: "m/86h/\(coinType)h/\(account)h", masterKey: masterKey)
    }

    /// Extended public key at `path` ("m" for the master itself) of extended private key
    /// `masterKey`. xpub for an xprv, tpub for a tprv.
    static func xpub(path: String, masterKey: String) -> String? {
        guard let key = try? DescriptorSecretKey.fromString(privateKey: masterKey) else { return nil }

        guard normalizedPath(path) != "m" else {
            return plainExtendedKey(key.asPublic().description)
        }

        guard let derivationPath = try? WalletLogic.BDKDerivationPath(path: normalizedPath(path)),
              let child = try? key.derive(path: derivationPath) else { return nil }

        return plainExtendedKey(child.asPublic().description)
    }

    /// The extended public key of an extended private key (xprv → xpub, tprv → tpub).
    static func xpub(fromXprv xprv: String) -> String? {
        return xpub(path: "m", masterKey: xprv)
    }

    /// Just the base58 key from a descriptor key string: drops a "[fingerprint/path]"
    /// origin and anything after the key ("/0/*", …).
    static func plainExtendedKey(_ descriptorKey: String) -> String {
        var key = Substring(descriptorKey)
        if let close = key.lastIndex(of: "]") { key = key[key.index(after: close)...] }
        if let slash = key.firstIndex(of: "/") { key = key[..<slash] }
        return String(key).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "m/…" form of a BIP32 path ("84'/0'/0'", "/0/1" and "m/84h/0h/0h" all accepted).
    static func normalizedPath(_ path: String) -> String {
        var p = path.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "H", with: "h")
        if p.hasPrefix("m") { p.removeFirst() }
        while p.hasPrefix("/") { p.removeFirst() }
        return p.isEmpty ? "m" : "m/" + p
    }

    /// Fields of a base58check extended key (78-byte payload, checksum verified).
    static func extendedKeyPayload(_ base58: String) -> (version: UInt32, depth: UInt8, parentFingerprint: UInt32, childNumber: UInt32, chainCode: Data, key: Data)? {
        let raw = Base58.decode(base58)
        guard raw.count == 82 else { return nil }
        let payload = Data(raw.prefix(78))
        guard Crypto.sha256hash(Crypto.sha256hash(payload)).prefix(4) == Data(raw.suffix(4)) else { return nil }
        let bytes = [UInt8](payload)
        func uint32(_ at: Int) -> UInt32 {
            bytes[at..<(at + 4)].reduce(0) { ($0 << 8) | UInt32($1) }
        }
        return (uint32(0), bytes[4], uint32(5), uint32(9), Data(bytes[13..<45]), Data(bytes[45..<78]))
    }

    /// Base58check extended key: version | depth | parent fingerprint | child number |
    /// chain code | key (33 bytes: 0x00 ‖ private key, or compressed public key).
    static func serializeExtendedKey(version: UInt32,
                                     depth: UInt8,
                                     parentFingerprint: UInt32,
                                     childNumber: UInt32,
                                     chainCode: Data,
                                     key: Data) -> String? {
        guard chainCode.count == 32, key.count == 33 else { return nil }
        func bigEndian(_ value: UInt32) -> [UInt8] {
            [UInt8(value >> 24 & 0xff), UInt8(value >> 16 & 0xff), UInt8(value >> 8 & 0xff), UInt8(value & 0xff)]
        }
        var payload = Data(bigEndian(version))
        payload.append(depth)
        payload.append(contentsOf: bigEndian(parentFingerprint))
        payload.append(contentsOf: bigEndian(childNumber))
        payload.append(chainCode)
        payload.append(key)
        return WalletLogic.Base58Check.encode(payload)
    }

    /// Compressed (33-byte) public key of a 32-byte private key.
    static func compressedPublicKey(privateKey: Data) -> Data? {
        guard let key = try? P256K.Signing.PrivateKey(dataRepresentation: privateKey) else { return nil }
        return Data(key.publicKey.dataRepresentation)
    }

    // MARK: - PSBT / transaction checks (BitcoinDevKit)

    /// True for a base64 PSBT. BitcoinDevKit parses it; anything that at least has the
    /// PSBT magic bytes is accepted too, so the node (which does the real decoding) gets
    /// to see it.
    static func validPsbt(_ psbt: String) -> Bool {
        if (try? WalletLogic.BDKPsbt(psbtBase64: psbt)) != nil { return true }
        guard let data = Data(base64Encoded: psbt) else { return false }
        return data.starts(with: [0x70, 0x73, 0x62, 0x74, 0xff])   // "psbt" 0xff
    }

    /// True for a hex-encoded raw transaction.
    static func validTx(_ tx: String) -> Bool {
        guard tx.count % 2 == 0, let bytes = Data(hexString: tx) else { return false }
        return (try? WalletLogic.BDKTransaction(transactionBytes: bytes)) != nil
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
                let localWalletStruct = Wallet(dictionary: wallet)
                let localWalletRecDesc = localWalletStruct.receiveDescriptor
                let localWalletChangeDesc = localWalletStruct.changeDescriptor
                let outputParentDescStr = Descriptor(parentDesc)
                
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
