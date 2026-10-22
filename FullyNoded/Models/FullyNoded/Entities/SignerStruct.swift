//
//  SignerStruct.swift
//  BitSense
//
//  Created by Peter on 04/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

public struct SignerStruct: CustomStringConvertible {
    
    let id:UUID
    let label:String
    let words:Data?
    let passphrase:Data?
    let added:Date
    let bip48xpub:Data?
    let bip48tpub:Data?
    let bip84tpub:Data?
    let bip84xpub:Data?
    let bip86tpub:Data?
    let bip86xpub:Data?
    let xfp:Data?
    let rootTpub:Data?
    let rootXpub:Data?
    /// Silent payment address and scan private key (encrypted), mainnet and test networks.
    /// Saved while the seed words exist, so they survive the words being deleted.
    let spAddress:Data?
    let spScanKey:Data?
    let spAddressTest:Data?
    let spScanKeyTest:Data?
    
    init(dictionary: [String: Any]) {
        id = dictionary["id"] as! UUID
        label = dictionary["label"] as? String ?? "Signer"
        words = dictionary["words"] as? Data
        passphrase = dictionary["passphrase"] as? Data
        xfp = dictionary["xfp"] as? Data
        added = dictionary["added"] as? Date ?? Date()
        
        bip48xpub = dictionary["bip48xpub"] as? Data
        bip48tpub = dictionary["bip48tpub"] as? Data
        
        bip84xpub = dictionary["bip84xpub"] as? Data
        bip84tpub = dictionary["bip84tpub"] as? Data
        
        bip86xpub = dictionary["bip86xpub"] as? Data
        bip86tpub = dictionary["bip86tpub"] as? Data
        
        rootXpub = dictionary["rootXpub"] as? Data
        rootTpub = dictionary["rootTpub"] as? Data
        
        spAddress = dictionary["spAddress"] as? Data
        spScanKey = dictionary["spScanKey"] as? Data
        spAddressTest = dictionary["spAddressTest"] as? Data
        spScanKeyTest = dictionary["spScanKeyTest"] as? Data
    }
    
    public var description: String {
        return ""
    }
}


/// A signer's silent payment address and scan private key, per network (mainnet uses coin
/// type 0, every test network coin type 1). Saved encrypted on the signer while its seed words
/// exist, so the address and scan key (for Fully Noded Server and detecting payments) keep
/// working after the words are deleted. The spend private key is never saved: a signer
/// without seed words can't spend, by design.
enum SignerSilentPayment {
    struct Info {
        let address: String
        let scanKey: String   // b_scan, 64 hex
    }

    /// Saved data, else derived from the seed words (with the signer's stored passphrase).
    static func info(for signer: SignerStruct, mainnet: Bool) -> Info? {
        saved(signer, mainnet: mainnet) ?? derive(signer, mainnet: mainnet)
    }

    static func saved(_ signer: SignerStruct, mainnet: Bool) -> Info? {
        guard let encAddress = mainnet ? signer.spAddress : signer.spAddressTest,
              let encKey = mainnet ? signer.spScanKey : signer.spScanKeyTest,
              let address = Crypto.decrypt(encAddress)?.utf8String,
              let scanKey = Crypto.decrypt(encKey)?.utf8String,
              !address.isEmpty, scanKey.count == 64 else { return nil }
        return Info(address: address, scanKey: scanKey)
    }

    /// From the seed words; nil once they're deleted.
    static func derive(_ signer: SignerStruct, mainnet: Bool) -> Info? {
        guard let encryptedWords = signer.words,
              var decryptedWords = Crypto.decrypt(encryptedWords),
              var words = decryptedWords.utf8String else { return nil }
        var passphrase = ""
        if let encryptedPassphrase = signer.passphrase,
           var decryptedPassphrase = Crypto.decrypt(encryptedPassphrase) {
            passphrase = decryptedPassphrase.utf8String ?? ""
            decryptedPassphrase.secureZero()
        }
        defer {
            decryptedWords.secureZero()
            words.secureWipe()
            passphrase.secureWipe()
        }
        guard let address = WalletLogic.shared.silentPaymentAddress(mnemonic: words, passphrase: passphrase, mainnet: mainnet),
              let scanKey = WalletLogic.shared.silentPaymentScanPrivateKey(mnemonic: words, passphrase: passphrase, mainnet: mainnet) else {
            return nil
        }
        return Info(address: address, scanKey: scanKey)
    }

    /// Saves both networks' data on the signer if its words exist and it isn't saved yet.
    /// Completion (main queue): true if the data is saved (now or already).
    static func ensureSaved(_ signer: SignerStruct, completion: ((Bool) -> Void)? = nil) {
        let done: (Bool) -> Void = { ok in DispatchQueue.main.async { completion?(ok) } }
        if saved(signer, mainnet: true) != nil, saved(signer, mainnet: false) != nil {
            done(true)
            return
        }
        DispatchQueue.global(qos: .utility).async {
            guard let main = derive(signer, mainnet: true), let test = derive(signer, mainnet: false),
                  let address = Crypto.encrypt(Data(main.address.utf8)),
                  let scanKey = Crypto.encrypt(Data(main.scanKey.utf8)),
                  let addressTest = Crypto.encrypt(Data(test.address.utf8)),
                  let scanKeyTest = Crypto.encrypt(Data(test.scanKey.utf8)) else {
                done(false)
                return
            }
            let values: [(String, Data)] = [("spAddress", address), ("spScanKey", scanKey),
                                            ("spAddressTest", addressTest), ("spScanKeyTest", scanKeyTest)]
            var remaining = values
            var allSaved = true
            func next() {
                guard let (key, value) = remaining.first else {
                    done(allSaved)
                    return
                }
                remaining.removeFirst()
                CoreDataService.update(id: signer.id, keyToUpdate: key, newValue: value, entity: .signers) { saved in
                    allSaved = allSaved && saved
                    next()
                }
            }
            next()
        }
    }

    /// Saves it for every signer that still has its words (once per signer).
    static func backfillAll() {
        CoreDataService.retrieveEntity(entityName: .signers) { signers in
            for dict in signers ?? [] {
                ensureSaved(SignerStruct(dictionary: dict))
            }
        }
    }

    /// B_spend (33 bytes) from a silent payment address.
    static func spendPublicKey(address: String) -> Data? {
        guard let decoded = try? WalletLogic.Bech32m.decode(address), decoded.2.count >= 66 else { return nil }
        return Data(decoded.2.dropFirst(33).prefix(33))
    }
}
