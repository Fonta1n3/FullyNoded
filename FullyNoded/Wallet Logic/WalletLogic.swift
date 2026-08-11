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
    typealias BDKNetwork = BitcoinDevKit.Network
    typealias BDKMnemonic = BitcoinDevKit.Mnemonic
    typealias BDKDerivationPath = BitcoinDevKit.DerivationPath
    typealias BDKAddress = BitcoinDevKit.Address
    typealias BDKTransaction = BitcoinDevKit.Transaction
    typealias BDKTxInput = BitcoinDevKit.TxIn
    typealias BDKPsbtInput = BitcoinDevKit.Input
    typealias BDKKeyChain = BitcoinDevKit.KeychainKind
       
    
    // TODO: Improve this so we use a random NUMS instead of a dummy key.
    func dummyKey() -> String? {
        guard var secretDataForDummyMnemonic = Crypto.secret() else { return nil }
        
        guard let dummyMnemonic = try? BDKMnemonic.fromEntropy(entropy: secretDataForDummyMnemonic) else { return nil }
        
        guard let network = bdkNetwork() else {
            return nil
        }
        
        guard var randomData = Crypto.secret() else { return nil }
        
        // Include random passphrase to add entropy to dummy master key.
        let hash = Crypto.sha256hash(Crypto.sha256hash(Crypto.sha256hash(randomData))).hex
        
        guard let dummyMk = bdkMasterKey(network: network, mnemonic: dummyMnemonic.description, passphrase: hash) else {
            return nil
        }
        
        let arr = dummyMk.asPublic().description.components(separatedBy: "/")
        
        defer {
            randomData.secureZero()
            secretDataForDummyMnemonic.secureZero()
        }
        
        return "\(arr[0])"
    }
    
    func fingerprint(masterKey: DescriptorSecretKey) -> String {
        return masterKey.asPublic().masterFingerprint()
    }
    
    func bdkMasterKey(network: BDKNetwork, mnemonic: String, passphrase: String?) -> DescriptorSecretKey? {
        guard let bdkMnemonic = try? Mnemonic.fromString(mnemonic: mnemonic) else { return nil }
        
        return DescriptorSecretKey(
            network: network,
            mnemonic: bdkMnemonic,
            password: passphrase ?? ""
        )
    }
    
    func persistor() -> Persister? {
        try? securelyDeleteWallet(name: "temp_wallet")
        
        let tempDbURL = walletDatabaseURL(named: "temp_wallet")
        
        return try? Persister.newSqlite(path: tempDbURL)
    }
    
    /// Takes in watch-only receive and change descriptors as strings, a mnemonic and optional passphrase to create a BDKWallet which we can use for signing psbts.
    func wallet(passphrase: String?,
                network: Network,
                mnemonic: Mnemonic,
                recDescStr: String,
                changeDesStr: String,
                completion: @escaping ((bdkWallet: BDKWallet?, errorMessage: String?)) -> Void) {
        
        let masterKey = DescriptorSecretKey(
            network: network,
            mnemonic: mnemonic,
            password: passphrase ?? ""
        )
                            
        hotDescriptor(watchOnlyDescriptor: Descriptor(recDescStr), masterKey: masterKey) { [weak self] hotRecDescString in
            guard let self = self else { return }
            
            guard var hotRecDescString = hotRecDescString else {
                //print("Fetching hotRecDescString failed.")
                return
            }
                        
            guard let hotReceiveBDKDescriptor = try? BDKDescriptor(descriptor: hotRecDescString, network: network) else {
                //print("Could not convert hot receive descriptor string to BDKDescriptor.")
                return
            }
            
            #if DEBUG
            print("hotRecDescString: \(hotRecDescString)")
            #endif
            
            hotDescriptor(watchOnlyDescriptor: Descriptor(changeDesStr), masterKey: masterKey) { [weak self] hotChangeDescString in
                guard let self = self else { return }
                
                guard var hotChangeDescString = hotChangeDescString else {
                    #if DEBUG
                    print("Fetching hotChangeDescString failed.")
                    #endif
                    return
                }
                
                #if DEBUG
                print("hotChangeDescString: \(hotChangeDescString)")
                #endif
                                
                guard let hotChangeBDKDescriptor = try? BDKDescriptor(descriptor: hotChangeDescString, network: network) else {
                    //print("Could not convert hot change descriptor string to BDKDescriptor.")
                    return
                }
                
                try? securelyDeleteWallet(name: "temp_wallet")
                                
                guard let database = persistor() else {
                    completion((nil, "Unable to securely delete temp_wallet."))
                    return
                }
                
                defer {
                    hotRecDescString.secureWipe()
                    hotChangeDescString.secureWipe()
                }
                
                #if DEBUG
                print("hotReceiveBDKDescriptor: \(hotReceiveBDKDescriptor.toStringWithSecret())")
                print("watchOnlyReceiveDescriptor: \(hotReceiveBDKDescriptor.description)")
                #endif
                
                do {
                    let bdkWallet = try BDKWallet(descriptor: hotReceiveBDKDescriptor, changeDescriptor: hotChangeBDKDescriptor, network: network, persister: database)
                                        
                    completion((bdkWallet, nil))
                    
                } catch {
                    #if DEBUG
                    print("error creating bdkwallet")
                    print(error.localizedDescription)
                    #endif
                    completion((nil, error.localizedDescription))
                }
            }
        }
    }
    
    func securelyDeleteWallet(name: String) throws {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dbURL = docs.appendingPathComponent("\(name).sqlite3")
        
        guard FileManager.default.fileExists(atPath: dbURL.path) else { return }
        
        // Overwrite with random data first.
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
    
    func signPsbt(wallet: BDKWallet, psbtBase64: String) -> ((signedPsbt: String?, rawTx: String?, errorMessage: String?)) {
        guard let psbt = try? BDKPsbt(psbtBase64: psbtBase64) else {
            return (nil, nil, "Failed converting bas64 psbt to BDKPsbt.")
        }
        
        let signOptions = SignOptions(
            trustWitnessUtxo: false,
            assumeHeight: nil,
            allowAllSighashes: false,
            tryFinalize: true,
            signWithTapInternalKey: true,
            allowGrinding: true
        )
        
        do {
            let finalized = try wallet.sign(psbt: psbt, signOptions: signOptions)
            try securelyDeleteWallet(name: "temp_wallet")
            
            if finalized {
                guard let tx = try? psbt.extractTx() else {
                    return (nil, nil, "Error extracting the raw transaction from the finalized psbt.")
                }
                return (nil, tx.serialize().hex, nil)
                
            } else {
                let signedBase64 = psbt.serialize()
                return (signedBase64, nil, nil)
            }
        } catch {
            return (nil, nil, error.localizedDescription)
        }
    }
    
    func bdkNetwork() -> BDKNetwork? {
        let network = UserDefaults.standard.object(forKey: "chain") as? String ?? "main"
        
        var bdkNetwork: BDKNetwork?
        
        switch network {
        case "main": bdkNetwork = .bitcoin
        case "test": bdkNetwork = .testnet
        case "regtest": bdkNetwork = .regtest
        case "signet": bdkNetwork = .signet
        case "testnet4": bdkNetwork = .testnet4
        default:
            break
        }
        
        return bdkNetwork
    }
    
    private func hotDescriptor(watchOnlyDescriptor: Descriptor, masterKey: DescriptorSecretKey, completion: @escaping((String?)) -> Void) {
        
        if watchOnlyDescriptor.isP2TR && watchOnlyDescriptor.isTimelocked, !watchOnlyDescriptor.isMulti {
            
            let derivation = watchOnlyDescriptor.derivation
            
            guard let path = try? BDKDerivationPath(path: derivation) else {
                return
            }
            
            guard let derivedKey = try? masterKey.derive(path: path) else {
                return
            }
            
            if derivedKey.asPublic().description.contains(watchOnlyDescriptor.accountXpub) {
                
                let derivedKeyStruct = Descriptor("tr(" + derivedKey.description + ")")
                let checksumless = "\(watchOnlyDescriptor.string.components(separatedBy: "#")[0])"
                
                #if DEBUG
                print("match here")
                print("checksumless: \(checksumless)")
                print("watchOnlyDescriptor.accountXpub: \(watchOnlyDescriptor.accountXpub)")
                print("derivedKeyStruct.accountXprv: \(derivedKeyStruct.accountXprv)")
                #endif
                
                let hotDescriptor = checksumless.replacingOccurrences(of: watchOnlyDescriptor.accountXpub, with: derivedKeyStruct.accountXprv)
                #if DEBUG
                print("hotDescriptor: \(hotDescriptor)")
                #endif
                completion((hotDescriptor))
            }
            
        } else if watchOnlyDescriptor.isMulti {
            var hotDescriptor: String?
            
            defer {
                hotDescriptor?.secureWipe()
            }
                        
            for (x, _) in watchOnlyDescriptor.multiSigKeys.enumerated() {
                                
                guard let path = try? BDKDerivationPath(path: watchOnlyDescriptor.derivationArray[x]) else {
                    return
                }
                
                guard let derivedKey = try? masterKey.derive(path: path) else {
                    return
                }
                                
                if derivedKey.asPublic().description.contains(watchOnlyDescriptor.multiSigKeys[x]) {
                    hotDescriptor = processMultiSig(derivedKey: derivedKey, watchOnlyDescriptor: watchOnlyDescriptor, keyIndex: x)
                }
                
                if x + 1 == watchOnlyDescriptor.multiSigKeys.count {
                    completion((hotDescriptor))
                }
            }
        } else {
            guard let path = try? BDKDerivationPath(path: watchOnlyDescriptor.derivation) else {
                completion((nil))
                return
            }
            
            guard let derivedKey = try? masterKey.derive(path: path) else {
                completion((nil))
                return
            }
            
            var xprvString = derivedKey.asPublic().description
            
            guard derivedKey.asPublic().description.contains(watchOnlyDescriptor.accountXpub) else {
                return
            }
            
            var processedHotDescriptor = processSingleSig(derivedKey: derivedKey, watchOnlyDescriptor: watchOnlyDescriptor)
            
            defer {
                xprvString.secureWipe()
                processedHotDescriptor.secureWipe()
            }
            
            completion((processedHotDescriptor))
        }
    }
    
    private func processSingleSig(derivedKey: DescriptorSecretKey, watchOnlyDescriptor: Descriptor) -> String {
        var derivedKeyString = derivedKey.description
        var derivedKeyArr = derivedKeyString.components(separatedBy: "]")
        var derivedKeyArr2 = derivedKeyArr[1].components(separatedBy: "/")
        var plainXprv = "\(derivedKeyArr2[0])"
        let coldDescArr = watchOnlyDescriptor.string.components(separatedBy: "#")
        let checksumLessWatchOnlyDesc = "\(coldDescArr[0])"
        
        defer {
            plainXprv.secureWipe()
            derivedKeyString.secureWipe()
            derivedKeyArr.removeAll()
            derivedKeyArr2.removeAll()
        }
        
        return checksumLessWatchOnlyDesc.replacingOccurrences(of: watchOnlyDescriptor.accountXpub, with: plainXprv)
    }
    
    private func processMultiSig(derivedKey: DescriptorSecretKey, watchOnlyDescriptor: Descriptor, keyIndex: Int) -> String {
        var derivedKeyString = derivedKey.description
        var derivedKeyArr = derivedKeyString.components(separatedBy: "]")
        var derivedKeyArr2 = derivedKeyArr[1].components(separatedBy: "/")
        var plainXprv = "\(derivedKeyArr2[0])"
        let coldDescArr = watchOnlyDescriptor.string.components(separatedBy: "#")
        let checksumLessWatchOnlyDesc = "\(coldDescArr[0])"
        
        defer {
            plainXprv.secureWipe()
            derivedKeyString.secureWipe()
            derivedKeyArr.removeAll()
            derivedKeyArr2.removeAll()
        }
        
        return checksumLessWatchOnlyDesc.replacingOccurrences(of: watchOnlyDescriptor.multiSigKeys[keyIndex], with: plainXprv)
    }
    
    enum CustomError: Error {
        case networkFailed(reason: String)
    }
    
    // Only used for sweeping a single utxo.
    func createPsbtWithManualInputs(
        wallet: BDKWallet,
        utxos: [Esplora_Utxo],
        outputs: [(address: String, amount: UInt64)],
        feeRate: Float? = nil,
        network: BDKNetwork
    ) throws -> BitcoinDevKit.Psbt? {
        var txBuilder = TxBuilder()
               
        for utxo in utxos {
            let txid = try Txid.fromString(hex: utxo.txid)
            let outpoint = OutPoint(txid: txid, vout: UInt32(utxo.vout))
            let address = try Address(address: utxo.address!, network: network)
            let script = address.scriptPubkey()
            let amount = Amount.fromSat(satoshi: UInt64(utxo.value))
            let txOutput = TxOut(value: amount, scriptPubkey: script)
            wallet.insertTxout(outpoint: outpoint, txout: txOutput)
            txBuilder = txBuilder.addUtxo(outpoint: outpoint)
        }
                        
        do {
            let syncRequest = try wallet.startSyncWithRevealedSpks().build()
            let onionRoot = "http://mempoolhqx4isw62xs7abwphsq7ldayuidyx2v2oethdhhj6mlo2r6ad.onion"
            let baseURL: String
            switch network {
            case .testnet: baseURL = "\(onionRoot)/testnet/api/"
            case .testnet4: baseURL = "\(onionRoot)/testnet4/api/"
            case .signet: baseURL = "\(onionRoot)/signet/api/"
            case .regtest:
                throw CustomError.networkFailed(reason: "Nodeless transaction creation does not work on regtest.")
            default:
                baseURL = "\(onionRoot)/api/"
            }
            
            let client = EsploraClient(url: baseURL, proxy: "http://localhost:9080")
            let sync = try client.sync(request: syncRequest, parallelRequests: 4)
            try wallet.applyUpdate(update: sync)
            
            for output in outputs {
                let address = try Address(address: output.address, network: network)
                txBuilder = txBuilder.drainTo(script: address.scriptPubkey())
            }
            
            let feeRate = try FeeRate.fromSatPerVb(satVb: UInt64(1))
            txBuilder = txBuilder.manuallySelectedOnly()
            txBuilder = txBuilder.feeRate(feeRate: feeRate)
            txBuilder = txBuilder.drainWallet()
            
//            if let internalPolicies = try? wallet.policies(keychain: .internal) {
//                if  internalPolicies.requiresPath() {
//                    let (topID, subID, _, _) = extractTimelockPolicyValues(from: internalPolicies.asString(), hotXfp: nil)
//                    
//                    if let topID, let subID {
//                        let policyPath: [String: [UInt64]] = [
//                            topID: [1],
//                            subID: [0, 1]
//                        ]
//                        
//                        txBuilder = txBuilder.policyPath(policyPath: policyPath, keychain: .internal)
//                    }
//                }
//            }
//           
//            if let externalPolicies = try? wallet.policies(keychain: .external) {
//                if externalPolicies.requiresPath() {
//                    let (topID, subID, _, _) = extractTimelockPolicyValues(from: externalPolicies.asString(), hotXfp: nil)
//                    
//                    if let topID, let subID {
//                        let policyPath: [String: [UInt64]] = [
//                            topID: [1],
//                            subID: [0, 1]
//                        ]
//                        
//                        txBuilder = txBuilder.policyPath(policyPath: policyPath, keychain: .external)
//                    }
//                }
//            }
            
            let psbt = try txBuilder.finish(wallet: wallet)
            
            do {
                try WalletLogic.shared.securelyDeleteWallet(name: "temp_wallet")
            }
            
            return psbt
            
        } catch {
            throw error
        }
    }
    
    enum WalletCreateError: Error {
        case unableToGetNetwork
        case unableToCreatePersistor
    }
    
    enum TimelockedAddressError: Error {
        case unableToGenerateDummyPubkey
        case unsupportedTimelockFormat
    }
    
    enum TimelockedSigningError: Error {
        case didNotSign
        case timelockNotMet
    }
    
    func bdkWalletFromDescriptors(recDesc: String, changeDesc: String) throws -> BDKWallet {
        guard let network = WalletLogic.shared.bdkNetwork() else {
            throw WalletCreateError.unableToGetNetwork
        }
        
        guard let persister = WalletLogic.shared.persistor() else {
            throw WalletCreateError.unableToCreatePersistor
        }
        
        do {
            let bdkPrimDesc = try WalletLogic.BDKDescriptor(descriptor: recDesc, network: network)
            let bdkChangeDesc = try WalletLogic.BDKDescriptor(descriptor: changeDesc, network: network)
            return try WalletLogic.BDKWallet(descriptor: bdkPrimDesc, changeDescriptor: bdkChangeDesc, network: network, persister: persister)
        } catch {
            throw error
        }
    }
    
    func createTimelockedAddress(fnWallet: Wallet, pubkey: String?, descriptor: String?, timelock: UInt32) throws -> (timelockedAddress: String, descriptor: String) {
        do {
            let fnDesc = Descriptor(fnWallet.receiveDescriptor)
            
            if fnDesc.isMulti && fnDesc.isP2TR, let descriptor = descriptor {
                let (dummyPubkey, checksumlessDesc) = try dummyPubkeyAndChecksumLessDesc(descriptor: descriptor)
                let nonRanged = nonRanged(desc: checksumlessDesc.string)
                let descriptorString = "tr(\(dummyPubkey),and_v(v:\(nonRanged),after(\(timelock))))"
                #if DEBUG
                print("timelocked multisig taproot descriptorString: \(descriptorString)")
                #endif
                return try fetchTimelockAddressFromDescString(descriptorString: descriptorString, fnWallet: fnWallet)
                
            } else if fnDesc.isP2TR, let descriptor = descriptor {
                let nonRanged = descriptor.replacingOccurrences(of: "*", with: "0")
                let (dummyPubkey, checksumlessDesc) = try dummyPubkeyAndChecksumLessDesc(descriptor: nonRanged)
                let trPrefixDesc = checksumlessDesc.string.replacingOccurrences(of: "tr(", with: "pk(")
                let descriptorString = "tr(\(dummyPubkey),and_v(v:\(trPrefixDesc),after(\(timelock))))"
                #if DEBUG
                print("timelocked single sig taproot descriptorString: \(descriptorString)")
                #endif
                return try fetchTimelockAddressFromDescString(descriptorString: descriptorString, fnWallet: fnWallet)
                
            } else if fnDesc.isP2WPKH && !fnDesc.isMulti, let descriptor = descriptor {
                let processed = processSegwitSingleSigDescForMiniScript(desc: descriptor)
                let miniscript = "and_v(v:\(processed),after(\(timelock)))"
                let descriptorString = "wsh(\(miniscript))"
                #if DEBUG
                print("timelocked single sig segwit descriptorString: \(descriptorString)")
                #endif
                return try fetchTimelockAddressFromDescString(descriptorString: descriptorString, fnWallet: fnWallet)
                
            } else if fnDesc.isMulti && fnDesc.isP2WPKH, let descriptor = descriptor {
                let processed = processSegwitMultisigDescForMiniScript(desc: descriptor)
                let miniScript = "and_v(v:\(processed),after(\(timelock)))"
                let descriptorString = "wsh(\(miniScript))"
                #if DEBUG
                print("timelocked multi sig segwit descriptorString: \(descriptorString)")
                #endif
                return try fetchTimelockAddressFromDescString(descriptorString: descriptorString, fnWallet: fnWallet)
                
            } else {
                throw TimelockedAddressError.unsupportedTimelockFormat
            }
        } catch {
            #if DEBUG
            print("cath here: \(error.localizedDescription)")
            #endif
            throw error
        }
    }
    
    private func checkSumless(desc: String) -> String {
        return "\(desc.components(separatedBy: "#")[0])"
    }
    
    private func nonRanged(desc: String) -> String {
        return desc.replacingOccurrences(of: "*", with: "0")
    }
    
    private func processSegwitSingleSigDescForMiniScript(desc: String) -> String {
        let checksumless = checkSumless(desc: desc)
        let nonRanged = nonRanged(desc: checksumless)
        let correctedNestedPrefix = nonRanged.replacingOccurrences(of: "wpkh(", with: "pk(")
        return correctedNestedPrefix
    }
    
    private func processSegwitMultisigDescForMiniScript(desc: String) -> String {
        let checksumless = checkSumless(desc: desc)
        let nonRanged = nonRanged(desc: checksumless)
        let removedNestedWsh = nonRanged.replacingOccurrences(of: "wsh(", with: "").replacingOccurrences(of: "))", with: ")")
        let multi = removedNestedWsh.replacingOccurrences(of: "sortedmulti", with: "multi")
        return multi
    }
    
   private func dummyPubkeyAndChecksumLessDesc(descriptor: String) throws -> (dummyPubkey: String, checksumlessDescriptor: Descriptor) {
        let checksumless = checkSumless(desc: descriptor)
        let checksumlessDesc = Descriptor(checksumless)
        guard let dummy = try dummyPubKey() else { throw TimelockedAddressError.unableToGenerateDummyPubkey }
        return (dummy, checksumlessDesc)
    }
    
    func fetchTimelockAddressFromDescString(descriptorString: String, fnWallet: Wallet) throws -> ((timelockedAddress: String, descriptor: String)) {
        let wallet = try bdkWalletFromDescriptors(recDesc: descriptorString, changeDesc: fnWallet.changeDescriptor)
        let addressInfo = wallet.peekAddress(keychain: .external, index: UInt32(0))
        return ((addressInfo.address.description, descriptorString))
    }
    
    func dummyPubKey() throws -> String? {
        guard let dummyXpub = dummyKey() else {
            throw TimelockedAddressError.unableToGenerateDummyPubkey
        }
        
        guard let pk = Keys.childPubkey(xpub: dummyXpub) else {
            throw TimelockedAddressError.unableToGenerateDummyPubkey
        }
        return pk
    }
    
    
//    func extractTimelockPolicyValues(from policyString: String?, hotXfp: String?) -> (topID: String?, subID: String?, timelock: UInt64?, hotFingerprint: String?) {
//        guard let policyString,
//              let jsonStart = policyString.range(of: "{")?.lowerBound,
//              let jsonEnd = policyString.range(of: "}", options: .backwards)?.upperBound else {
//            return (nil, nil, nil, nil)
//        }
//        
//        let json = String(policyString[jsonStart..<jsonEnd])
//        guard let data = json.data(using: .utf8) else {
//            return (nil, nil, nil, nil)
//        }
//        
//        do {
//            guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
//                return (nil, nil, nil, nil)
//            }
//            
//            // Top-level THRESH (1-of-2 branches)
//            let topID = jsonObject["id"] as? String
//            
//            guard let items = jsonObject["items"] as? [[String: Any]],
//                  items.count == 2 else {
//                return (topID, nil, nil, nil)
//            }
//            
//            // Look for the inner THRESH (the one with MULTISIG + timelock)
//            var subID: String?
//            var timelockValue: UInt64?
//            var hotFingerprint: String?
//            
//            for item in items {
//                guard let itemType = item["type"] as? String,
//                      itemType == "THRESH",
//                      let itemID = item["id"] as? String,
//                      let itemThreshold = item["threshold"] as? Int,
//                      itemThreshold == 2,
//                      let subItems = item["items"] as? [[String: Any]],
//                      subItems.count == 2 else {
//                    continue
//                }
//                
//                subID = itemID
//                
//                // Now look inside this sub-THRESH's items
//                for sub in subItems {
//                    guard let subType = sub["type"] as? String else { continue }
//                    
//                    if subType == "MULTISIG",
//                       let keys = sub["keys"] as? [[String: Any]] {
//                        let fps = keys.compactMap({ $0["fingerprint"] as? String })
//                        if let hotXfp = hotXfp,
//                            fps.contains(hotXfp) {
//                            hotFingerprint = hotXfp
//                         }
//                    }
//                    else if subType == "ABSOLUTETIMELOCK",
//                            let val = sub["value"] as? UInt64 {
//                        timelockValue = val
//                    }
//                }
//                
//                // We found the interesting branch → can break early
//                if subID != nil && (timelockValue != nil || hotFingerprint != nil) {
//                    break
//                }
//            }
//            
//            return (topID, subID, timelockValue, hotFingerprint)
//            
//        } catch {
//            #if DEBUG
//            print("Policy JSON parse error: \(error)")
//            #endif
//            return (nil, nil, nil, nil)
//        }
//    }
    
}

