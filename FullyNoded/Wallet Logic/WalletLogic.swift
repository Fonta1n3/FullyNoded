//
//  WalletLogic.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/20/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import Foundation
import BitcoinDevKit

class WalletLogic {
    static let shared = WalletLogic()
    
    private init(){}
    
    // Rename the BDK types so they don’t clash with ours.
    typealias BDKWallet = BitcoinDevKit.Wallet
    typealias BDKDescriptor = BitcoinDevKit.Descriptor
    //typealias BDKAddressInfo = BitcoinDevKit.AddressInfo
    typealias BDKPsbt = BitcoinDevKit.Psbt
    //typealias BDKDerivationPath = BitcoinDevKit.DerivationPath
    
    // Takes in any receive and change descriptor as strings and a mnemonic/passphrase to create a BDKWallet which we can use for signing psbts.
    func wallet(passphrase: String?, network: Network, mnemonic: Mnemonic, recDescStr: String, changeDesStr: String) -> BDKWallet? {
        let masterKeyWithPassphrase = DescriptorSecretKey(
            network: network,
            mnemonic: mnemonic,
            password: passphrase ?? ""
        )
        
        guard let receiveDescriptor = try? BDKDescriptor(descriptor: recDescStr, network: network) else {
            print("Could not convert receive descriptor string to BDKDescriptor.")
            return nil
        }
        
        guard let changeDescriptor = try? BDKDescriptor(descriptor: changeDesStr, network: network) else {
            print("Could not convert change descriptor string to BDKDescriptor.")
            return nil
        }
                
        let tempDbURL = walletDatabaseURL(named: "temp_wallet")
        
        guard let database = try? Persister.newSqlite(path: tempDbURL) else {
            return nil
        }
        
        return try? BDKWallet(descriptor: receiveDescriptor, changeDescriptor: changeDescriptor, network: network, persister: database)
    }
    
    func securelyDeleteWallet(name: String) throws {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dbURL = docs.appendingPathComponent("\(name).sqlite3")
        
        guard FileManager.default.fileExists(atPath: dbURL.path) else { return }
        
        // Overwrite with random data first (optional but paranoid)
        let fileHandle = try FileHandle(forWritingTo: dbURL)
        let randomData = Data((0..<Int(64_000)).map { _ in UInt8.random(in: 0...255) })
        try fileHandle.write(contentsOf: randomData)
        try fileHandle.write(contentsOf: randomData)  // twice is enough
        try fileHandle.close()
        
        // Then delete
        try FileManager.default.removeItem(at: dbURL)
    }
    
    func walletDatabaseURL(named walletName: String) -> String {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("\(walletName).sqlite3").absoluteString
    }
    
    func signPsbt(wallet: BDKWallet, psbtBase64: String) -> String? {
        guard var psbt = try? BDKPsbt(psbtBase64: psbtBase64) else {
            print("failed converting bas64 psbt to")
            return nil
        }
        
        let signOptions = SignOptions(
            trustWitnessUtxo: false,
            assumeHeight: nil,
            allowAllSighashes: false,
            tryFinalize: true,
            signWithTapInternalKey: true,
            allowGrinding: true
        )
        
        guard let finalized = try? wallet.sign(psbt: psbt, signOptions: signOptions) else {
            print("signing failed")
            return nil
        }
        
        print("Signed successfully!")
        
        if finalized {
            print("Fully finalized!")
            
            guard let tx = try? psbt.extractTx() else {
                print("Error extracting the raw transaction from the finalized psbt.")
                return nil
            }
            print("raw tx: \(tx.serialize().hex)")
            return tx.serialize().hex
            
        } else {
            // 5. Return signed PSBT (base64)
            let signedBase64 = psbt.serialize()
            print("signedBase64: \(signedBase64)")
            return signedBase64
        }
        
    }
}

