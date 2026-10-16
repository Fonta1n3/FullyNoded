//
//  WalletLogic.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/20/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import Foundation
import BitcoinDevKit
import P256K

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
       
    
    /// BIP341 NUMS point H (x-only, even Y): lift_x(SHA256(G uncompressed)). Nobody
    /// knows its private key.
    static let numsH = "50929b74c1a04954b78b4b6035e97a5e078a5a0f28ec96d547bfee9ace803ac0"

    /// Unspendable (NUMS) taproot internal key, as an extended public key (xpub on
    /// mainnet, tpub otherwise) so callers can use it in descriptors and derive children
    /// from it (Keys.childPubkey).
    ///
    /// The public key is H + r·G, where H is the BIP341 NUMS point and r is random. BIP341
    /// recommends this so the internal key isn't recognisable on-chain as H. Nobody knows
    /// the discrete log of H, so nobody knows the private key of H + r·G, and the key path
    /// can never be spent. Non-hardened children only add public tweaks, so they're
    /// unspendable too. The chain code is random.
    ///
    /// r is not stored. Keeping r would let you PROVE unspendability to a third party;
    /// without it the key is still unspendable, just not provably so.
    func dummyKey() -> String? {
        guard let network = bdkNetwork() else { return nil }

        // Random tweak r and chain code (Crypto.secret() = 32 random bytes).
        guard var r = Crypto.secret(), r.count == 32,
              let chainCode = Crypto.secret(), chainCode.count == 32 else { return nil }
        defer { r.secureZero() }

        // K = H + r·G (compressed). Fails only if r ≥ n or K is infinity (negligible).
        guard let hData = SPHex.decode("02" + WalletLogic.numsH),
              let h = try? P256K.Signing.PublicKey(dataRepresentation: hData, format: .compressed),
              let k = try? h.add(Array(r)) else { return nil }
        let key = Data(k.dataRepresentation)
        guard key.count == 33 else { return nil }

        // BIP32 serialization: version | depth | parent fingerprint | child number | chain code | key.
        let version: [UInt8] = network == .bitcoin ? [0x04, 0x88, 0xB2, 0x1E]   // xpub
                                                    : [0x04, 0x35, 0x87, 0xCF]   // tpub
        let fourZeros: [UInt8] = [0, 0, 0, 0]
        var payload = Data()
        payload.append(contentsOf: version)
        payload.append(0)                            // depth 0
        payload.append(contentsOf: fourZeros)        // parent fingerprint
        payload.append(contentsOf: fourZeros)        // child number
        payload.append(chainCode)                    // 32 bytes
        payload.append(key)                          // 33 bytes
        return Base58Check.encode(payload)
    }

    /// Base58Check (used above to serialize the NUMS extended public key).
    enum Base58Check {
        private static let alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".utf8)

        static func encode(_ payload: Data) -> String {
            // payload || first 4 bytes of SHA256(SHA256(payload)).
            let checksum = Crypto.sha256hash(Crypto.sha256hash(payload)).prefix(4)
            let bytes = [UInt8](payload) + [UInt8](checksum)
            // Leading zero bytes become leading "1"s.
            var zeros = 0
            while zeros < bytes.count && bytes[zeros] == 0 { zeros += 1 }
            // Base-256 → base-58, digits stored least significant first.
            var digits: [UInt8] = []
            for byte in bytes {
                var carry = Int(byte)
                for i in 0..<digits.count {
                    carry += Int(digits[i]) << 8
                    digits[i] = UInt8(carry % 58)
                    carry /= 58
                }
                while carry > 0 {
                    digits.append(UInt8(carry % 58))
                    carry /= 58
                }
            }
            let chars = [UInt8](repeating: alphabet[0], count: zeros) + digits.reversed().map { alphabet[Int($0)] }
            return String(decoding: chars, as: UTF8.self)
        }
    }

    func fingerprint(masterKey: DescriptorSecretKey) -> String {
        return masterKey.asPublic().masterFingerprint()
    }
    
    func bdkMasterKey(network: BDKNetwork, mnemonic: String, passphrase: String?) -> DescriptorSecretKey? {
        guard let bdkMnemonic = try? Mnemonic.fromString(mnemonic: mnemonic) else { return nil }
        
        return DescriptorSecretKey(
            networkKind: networkKind(network: network),
            mnemonic: bdkMnemonic,
            password: passphrase ?? ""
        )
    }
    
    func networkKind(network: Network) -> NetworkKind {
        switch network {
        case .bitcoin: return .main
        default:
            return .test
        }
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
            networkKind: networkKind(network: network),
            mnemonic: mnemonic,
            password: passphrase ?? ""
        )
                            
        hotDescriptor(watchOnlyDescriptor: Descriptor(recDescStr), masterKey: masterKey) { [weak self] hotRecDescString in
            guard let self = self else { return }
            
            guard var hotRecDescString = hotRecDescString else {
                // This signer's keys (with this passphrase) aren't in the receive descriptor.
                completion((nil, "This signer's keys aren't in this wallet (wrong signer or passphrase?)."))
                return
            }
                        
            guard let hotReceiveBDKDescriptor = try? BDKDescriptor(descriptor: hotRecDescString, networkKind: networkKind(network: network)) else {
                completion((nil, "Could not build the signing receive descriptor."))
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
                    completion((nil, "This signer's keys aren't in this wallet's change descriptor."))
                    return
                }
                
                #if DEBUG
                print("hotChangeDescString: \(hotChangeDescString)")
                #endif
                                
                guard let hotChangeBDKDescriptor = try? BDKDescriptor(descriptor: hotChangeDescString, networkKind: networkKind(network: network)) else {
                    completion((nil, "Could not build the signing change descriptor."))
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
    
    /// Folder for BDK's temporary signing database: Application Support/BDK.
    /// Not Documents (visible in the Files app / Finder because UIFileSharingEnabled is
    /// on), excluded from backups, and unreadable while the device is locked.
    func bdkDirectory() -> URL? {
        let fm = FileManager.default
        guard let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        var dir = base.appendingPathComponent("BDK", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            do {
                try fm.createDirectory(at: dir,
                                       withIntermediateDirectories: true,
                                       attributes: [.protectionKey: FileProtectionType.complete])
            } catch {
                return nil
            }
        }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? dir.setResourceValues(values)
        return dir
    }
    
    /// Overwrites (best effort; flash storage may keep old blocks) and deletes the
    /// temporary BDK database and its SQLite side files (-wal, -shm, -journal), both in
    /// the current location and in Documents, where older versions kept it.
    /// Never throws for a failed delete, so it can't turn a successful signing into an error.
    func securelyDeleteWallet(name: String) throws {
        let fm = FileManager.default
        var folders: [URL] = []
        if let dir = bdkDirectory() { folders.append(dir) }
        if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first { folders.append(docs) }
        
        for folder in folders {
            for suffix in ["", "-wal", "-shm", "-journal"] {
                let url = folder.appendingPathComponent("\(name).sqlite3\(suffix)")
                guard fm.fileExists(atPath: url.path) else { continue }
                
                let attributes = try? fm.attributesOfItem(atPath: url.path)
                let size = (attributes?[.size] as? NSNumber)?.intValue ?? 0
                if size > 0, let handle = try? FileHandle(forWritingTo: url) {
                    let randomData = Data((0..<size).map { _ in UInt8.random(in: 0...255) })
                    try? handle.write(contentsOf: randomData)
                    try? handle.close()
                }
                try? fm.removeItem(at: url)
            }
        }
    }
    
    /// Removes files older app versions left in Documents (visible in Files / Finder).
    /// Only app-named files are touched; anything the user put there is left alone.
    func cleanUpLegacyDocuments() {
        try? securelyDeleteWallet(name: "temp_wallet")
        
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        for name in ["FullyNodedPSBT.psbt", "FullyNodedMultisig.txt"] {
            try? fm.removeItem(at: docs.appendingPathComponent(name))
        }
    }
    
    /// Plain file path of the temporary BDK database (not a file:// URL string).
    func walletDatabaseURL(named walletName: String) -> String {
        let dir = bdkDirectory() ?? FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("\(walletName).sqlite3").path
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
                completion((nil))
                return
            }
            
            guard let derivedKey = try? masterKey.derive(path: path) else {
                completion((nil))
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
            } else {
                // Key doesn't belong to this descriptor.
                completion((nil))
            }
            
        } else if watchOnlyDescriptor.isMulti {
            var hotDescriptor: String?
            
            defer {
                hotDescriptor?.secureWipe()
            }
                                    
            for (x, _) in watchOnlyDescriptor.multiSigKeys.enumerated() {
                // A key we can't derive just isn't ours; keep checking the others.
                guard x < watchOnlyDescriptor.derivationArray.count,
                      let path = try? BDKDerivationPath(path: watchOnlyDescriptor.derivationArray[x]),
                      let derivedKey = try? masterKey.derive(path: path) else {
                    continue
                }
                                
                if derivedKey.asPublic().description.contains(watchOnlyDescriptor.multiSigKeys[x]) {
                    hotDescriptor = processMultiSig(derivedKey: derivedKey, watchOnlyDescriptor: watchOnlyDescriptor, keyIndex: x)
                }
            }
            
            // Always report back: the hot descriptor, or nil if none of our keys matched.
            completion((hotDescriptor))
        } else {
            guard let path = try? BDKDerivationPath(path: watchOnlyDescriptor.derivation) else {
                completion((nil))
                return
            }
            
            guard let derivedKey = try? masterKey.derive(path: path) else {
                completion((nil))
                return
            }
            
            // A raw public key (e.g. Core's combo([fp/0'/0'/5']03…)): the key at its origin path
            // must be exactly that public key; it's replaced by the xprv at that path (no
            // wildcard, so it signs for that one key).
            if watchOnlyDescriptor.accountXpub.isEmpty {
                completion(Self.hotRawKeyDescriptor(watchOnlyDescriptor: watchOnlyDescriptor, derivedKey: derivedKey))
                return
            }
            
            var xprvString = derivedKey.asPublic().description
            
            guard derivedKey.asPublic().description.contains(watchOnlyDescriptor.accountXpub) else {
                completion((nil))
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
    
    /// Signing descriptor for a single raw public key: nil unless the key derived at its origin
    /// path has exactly that public key.
    private static func hotRawKeyDescriptor(watchOnlyDescriptor: Descriptor, derivedKey: DescriptorSecretKey) -> String? {
        let rawKey = watchOnlyDescriptor.pubkey.lowercased()
        guard rawKey.count == 66,
              let derivedPub = Keys.compressedPublicKey(privateKey: Data(derivedKey.secretBytes())),
              derivedPub.map({ String(format: "%02x", $0) }).joined() == rawKey else { return nil }
        // derivedKey.description is "[fp/path]xprv…": the plain xprv after the origin.
        let parts = derivedKey.description.components(separatedBy: "]")
        guard parts.count > 1, let xprv = parts[1].components(separatedBy: "/").first, !xprv.isEmpty else { return nil }
        let checksumless = watchOnlyDescriptor.string.components(separatedBy: "#")[0]
        let hot = checksumless.replacingOccurrences(of: watchOnlyDescriptor.pubkey, with: xprv)
        return hot == checksumless ? nil : hot
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
    
    /// Builds a PSBT spending exactly `utxos` with BDK, without syncing the wallet: each coin's
    /// funding transaction is fetched (one Esplora lookup per transaction), the coin's address is
    /// revealed in the wallet, and the transactions are handed to BDK as unconfirmed ones, which
    /// makes the coins real wallet utxos (BDK then fills in every PSBT field from the descriptor).
    /// The chain's amounts are used, and must match the cached ones.
    func createPsbtWithManualInputs(
        wallet: BDKWallet,
        utxos: [Esplora_Utxo],
        outputs: [(address: String, amount: UInt64)],
        feeRate: Float? = nil,
        network: BDKNetwork
    ) throws -> BitcoinDevKit.Psbt? {
        
        var cachedUtxos: [[String: Any]] = []
        let group = DispatchGroup()
        group.enter()
        CoreDataService.retrieveEntity(entityName: .utxos) { result in
            cachedUtxos = result ?? []
            group.leave()
        }
        group.wait()
        let cached = cachedUtxos.map { UTXO(from: $0) }
        func cachedUtxo(_ utxo: Esplora_Utxo) -> UTXO? {
            cached.first { $0.txid.lowercased() == utxo.txid.lowercased() && $0.vout == utxo.vout }
        }
        
        guard EsploraAPI.apiBase(network: network) != nil else {
            throw CustomError.networkFailed(reason: "Nodeless transaction creation does not work on regtest.")
        }
        
        // 1. Funding transactions (once per txid), checked against the cache.
        var fundingTxs: [String: Transaction] = [:]
        for utxo in utxos {
            let key = utxo.txid.lowercased()
            if fundingTxs[key] == nil {
                fundingTxs[key] = try EsploraAPI.transaction(txid: utxo.txid, network: network)
            }
            guard let tx = fundingTxs[key], tx.output().indices.contains(utxo.vout) else {
                throw CustomError.networkFailed(reason: "\(utxo.txid):\(utxo.vout) doesn't exist on chain.")
            }
            let out = tx.output()[utxo.vout]
            if let addressString = utxo.address {
                let address = try Address(address: addressString, network: network)
                guard address.scriptPubkey().toBytes() == out.scriptPubkey.toBytes() else {
                    throw CustomError.networkFailed(reason: "\(utxo.txid):\(utxo.vout) on chain doesn't pay \(addressString). Refresh your utxos.")
                }
            }
            guard out.value.toSat() == UInt64(utxo.value) else {
                throw CustomError.networkFailed(reason: "\(utxo.txid):\(utxo.vout) holds \(out.value.toSat()) sats on chain, not the cached \(utxo.value). Refresh your utxos.")
            }
            
            // 2. Reveal the coin's address so the wallet owns it.
            try revealAddress(of: out.scriptPubkey, in: wallet, hint: cachedUtxo(utxo)?.desc)
        }
        
        // 3. The funding transactions become wallet transactions; each coin must now be a utxo.
        let now = UInt64(Date().timeIntervalSince1970)
        wallet.applyUnconfirmedTxs(unconfirmedTxs: fundingTxs.values.map { UnconfirmedTx(tx: $0, lastSeen: now) })
        
        var txBuilder = TxBuilder()
        for utxo in utxos {
            let outpoint = OutPoint(txid: try Txid.fromString(hex: utxo.txid), vout: UInt32(utxo.vout))
            guard wallet.getUtxo(op: outpoint) != nil else {
                throw CustomError.networkFailed(reason: "\(utxo.txid):\(utxo.vout) isn't spendable by this wallet's descriptor.")
            }
            txBuilder = txBuilder.addUtxo(outpoint: outpoint)
        }
        
        // Timelock: the wallet descriptor's after(N), else a cached witness script's CLTV.
        var appliedLocktime = extractAfterLocktime(from: wallet.publicDescriptor(keychain: .external).description)
            ?? extractAfterLocktime(from: wallet.publicDescriptor(keychain: .internal).description)
        if appliedLocktime == nil {
            for utxo in utxos {
                if let hex = cachedUtxo(utxo)?.witnessScript,
                   let locktime = extractCLTV(fromWitnessScript: hex) ?? extractCLTVFromAsmOrHex(hex) {
                    appliedLocktime = locktime
                }
            }
        }
        if let appliedLocktime {
            if appliedLocktime >= 500_000_000 {
                txBuilder = txBuilder.nlocktime(locktime: .seconds(consensusTime: appliedLocktime))
            } else {
                txBuilder = txBuilder.nlocktime(locktime: .blocks(height: appliedLocktime))
            }
        }
        
        for output in outputs {
            let address = try Address(address: output.address, network: network)
            txBuilder = txBuilder.drainTo(script: address.scriptPubkey())
        }
        
        // sat/vB × 250 = sat per 1,000 weight units (1 vB = 4 wu), so fractional rates aren't truncated.
        let satPerKwu = UInt64((Double(max(1, feeRate ?? 1)) * 250).rounded(.up))
        // No onlyWitnessUtxo(): the wallet has the full funding transactions, so segwit v0 inputs
        // get their non_witness_utxo, which signing (trustWitnessUtxo: false) requires.
        txBuilder = txBuilder
            .manuallySelectedOnly()
            .feeRate(feeRate: FeeRate.fromSatPerKwu(satKwu: satPerKwu))
        
        if let policies = try? wallet.policies(keychain: .external), policies.requiresPath() {
            let (topID, subID, _, _) = extractTimelockPolicyValues(from: policies.asString(), hotXfp: nil)
            if let topID, let subID {
                txBuilder = txBuilder.policyPath(
                    policyPath: [topID: [1], subID: [0, 1]],
                    keychain: .external
                )
            }
        }
        
        let psbt = try txBuilder.finish(wallet: wallet)
        try? WalletLogic.shared.securelyDeleteWallet(name: "temp_wallet")
        return psbt
    }
    

    /// Reveals (up to) the address paying `spk` in `wallet`, so its coins count as the wallet's.
    /// `hint` is the coin's descriptor from listunspent (`…/0/5]…` → external index 5); without
    /// one the first addresses of both keychains are searched. Throws if the script isn't the
    /// wallet's.
    private func revealAddress(of spk: Script, in wallet: BDKWallet, hint: String?) throws {
        let target = spk.toBytes()
        if let known = wallet.derivationOfSpk(spk: spk) {
            _ = wallet.revealAddressesTo(keychain: known.keychain, index: known.index)
            return
        }
        // From the coin's own descriptor path: the last "/<0|1>/<index>" before a "]".
        if let hint = hint,
           let match = hint.range(of: #"/([01])/(\d+)\]"#, options: [.regularExpression, .backwards]) {
            let parts = hint[match].dropFirst().dropLast().split(separator: "/")
            if parts.count == 2, let branch = Int(parts[0]), let index = UInt32(parts[1]) {
                let keychain: KeychainKind = branch == 1 ? .internal : .external
                if wallet.peekAddress(keychain: keychain, index: index).address.scriptPubkey().toBytes() == target {
                    _ = wallet.revealAddressesTo(keychain: keychain, index: index)
                    return
                }
            }
        }
        // Search (non-ranged descriptors, e.g. a timelocked address, are index 0).
        for keychain in [KeychainKind.external, .internal] {
            for index in UInt32(0)..<2000 {
                if wallet.peekAddress(keychain: keychain, index: index).address.scriptPubkey().toBytes() == target {
                    _ = wallet.revealAddressesTo(keychain: keychain, index: index)
                    return
                }
            }
        }
        throw CustomError.networkFailed(reason: "This coin's address isn't derived from the wallet's descriptor.")
    }

    func extractAfterLocktime(from text: String) -> UInt32? {
        let pattern = #"after\((\d+)\)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text),
           let value = UInt32(text[range]) {
            return value
        }
        
        // 2. Policy JSON from policies.asString()
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        return findLocktime(in: json)
    }

    private func findLocktime(in json: Any) -> UInt32? {
        if let dict = json as? [String: Any] {
            let type = (dict["type"] as? String)?.uppercased() ?? ""
            
            let isLock =
                type == "AFTER" ||
                type == "TIMELOCK" ||
                type == "ABSOLUTELOCKTIME" ||
                type == "CHECKLOCKTIME" ||
                type.contains("LOCKTIME")
            
            if isLock {
                if let n = dict["value"] as? UInt32 { return n }
                if let n = dict["locktime"] as? UInt32 { return n }
                if let n = dict["timestamp"] as? UInt32 { return n }
                if let n = dict["value"] as? Int { return UInt32(n) }
                if let s = dict["value"] as? String, let n = UInt32(s) { return n }
            }
            
            for value in dict.values {
                if let found = findLocktime(in: value) {
                    return found
                }
            }
        } else if let array = json as? [Any] {
            for item in array {
                if let found = findLocktime(in: item) {
                    return found
                }
            }
        }
        return nil
    }

    private func extractCLTVFromAsmOrHex(_ script: String) -> UInt32? {
        if let fromExisting = extractCLTV(fromWitnessScript: script) {
            return fromExisting
        }
        
        // ASM: "... 1787666681 OP_CHECKLOCKTIMEVERIFY"
        let parts = script.split(whereSeparator: { $0.isWhitespace })
        if let cltvIndex = parts.firstIndex(where: { $0.uppercased().contains("CHECKLOCKTIMEVERIFY") }),
           cltvIndex > parts.startIndex {
            let prev = String(parts[parts.index(before: cltvIndex)])
            if let value = UInt32(prev) {
                return value
            }
        }
        
        // Hex: ... <push locktime> b1
        guard let data = Data(hexString: script) else { return nil }
        var i = 0
        while i < data.count {
            let op = data[i]
            if (1...75).contains(op) {
                let len = Int(op)
                let start = i + 1
                let end = start + len
                guard end <= data.count else { return nil }
                let payload = data[start..<end]
                let next = end < data.count ? data[end] : 0
                if next == 0xb1 { // OP_CHECKLOCKTIMEVERIFY
                    var value: UInt64 = 0
                    for (idx, byte) in payload.enumerated() {
                        value |= UInt64(byte) << (8 * idx)
                    }
                    return UInt32(value)
                }
                i = end
                continue
            }
            i += 1
        }
        return nil
    }
    
    func extractCLTV(fromWitnessScript hex: String) -> UInt32? {
        guard let data = Data(hexString: hex) else { return nil }
        var i = 0
        while i < data.count {
            let op = data[i]
            i += 1
            
            // data push (OP_PUSHDATA not handled for brevity – add if needed)
            if op > 0 && op <= 75 {
                let len = Int(op)
                guard i + len <= data.count else { return nil }
                let push = data[i ..< i+len]
                i += len
                
                // next byte is OP_CHECKLOCKTIMEVERIFY?
                if i < data.count && data[i] == 0xb1 {
                    // interpret push as little-endian script number
                    var value: UInt32 = 0
                    for (idx, byte) in push.enumerated() {
                        value |= UInt32(byte) << (8 * idx)
                    }
                    return value
                }
            }
        }
        return nil
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
    
    /// Verifies LOCALLY (no node involved) that `address` is derived from `fnWallet`'s
    /// receive or change descriptor.
    ///
    /// `keyPath` comes from the node (getaddressinfo hdkeypath / desc) and is only used as
    /// a hint for WHICH index to derive. Both branches are derived at that index and
    /// compared with the address, so a dishonest node can't make its own address pass as
    /// "ours" or "change". Whether it's change is decided here, not by the node.
    func locallyVerifyAddress(_ address: String, keyPath: String, fnWallet: Wallet) -> (isOurs: Bool, isChange: Bool) {
        // Last path element is the address index; hardened ("5h"/"5'") never matches.
        guard let last = keyPath.split(separator: "/").last,
              let index = UInt32(last),
              let bdkWallet = try? bdkWalletFromDescriptors(recDesc: fnWallet.receiveDescriptor,
                                                            changeDesc: fnWallet.changeDescriptor) else {
            return (false, false)
        }
        
        let target = normalizedAddress(address)
        
        if normalizedAddress(bdkWallet.peekAddress(keychain: .external, index: index).address.description) == target {
            return (true, false)
        }
        if normalizedAddress(bdkWallet.peekAddress(keychain: .internal, index: index).address.description) == target {
            return (true, true)
        }
        return (false, false)
    }
    
    /// Bech32(m) addresses are case-insensitive; base58 addresses are not.
    private func normalizedAddress(_ address: String) -> String {
        let trimmed = address.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
        let lower = trimmed.lowercased()
        if lower.hasPrefix("bc1") || lower.hasPrefix("tb1") || lower.hasPrefix("bcrt1") {
            return lower
        }
        return trimmed
    }
    
    func bdkWalletFromDescriptors(recDesc: String, changeDesc: String) throws -> BDKWallet {
        guard let network = WalletLogic.shared.bdkNetwork() else {
            throw WalletCreateError.unableToGetNetwork
        }
        
        guard let persister = WalletLogic.shared.persistor() else {
            throw WalletCreateError.unableToCreatePersistor
        }
        
        do {
            let bdkPrimDesc = try WalletLogic.BDKDescriptor(descriptor: recDesc, networkKind: networkKind(network: network))
            let bdkChangeDesc = try WalletLogic.BDKDescriptor(descriptor: changeDesc, networkKind: networkKind(network: network))
            return try WalletLogic.BDKWallet(descriptor: bdkPrimDesc, changeDescriptor: bdkChangeDesc, network: network, persister: persister)
        } catch {
            throw error
        }
    }
    
    /// `keyIndex` is the child index of the address being locked (taken from its hdkeypath), so the
    /// timelock uses that address's own key rather than always child 0.
    func createTimelockedAddress(fnWallet: Wallet, pubkey: String?, descriptor: String?, timelock: UInt32, keyIndex: UInt32 = 0, derivedDescriptor: String? = nil) throws -> (timelockedAddress: String, descriptor: String) {
        do {
            let fnDesc = Descriptor(fnWallet.receiveDescriptor)
            
            if fnDesc.isMulti && fnDesc.isP2TR, let descriptor = descriptor {
                let (dummyPubkey, checksumlessDesc) = try dummyPubkeyAndChecksumLessDesc(descriptor: descriptor)
                let nonRanged = nonRanged(desc: checksumlessDesc.scriptPath, index: keyIndex)
                let descriptorString = "tr(\(dummyPubkey),and_v(v:\(nonRanged),after(\(timelock))))"
                #if DEBUG
                print("timelocked multisig taproot descriptorString: \(descriptorString)")
                #endif
                return try fetchTimelockAddressFromDescString(descriptorString: descriptorString, fnWallet: fnWallet)
                
            } else if fnDesc.isP2TR, let descriptor = descriptor {
                let nonRanged = nonRanged(desc: descriptor, index: keyIndex)
                let (dummyPubkey, checksumlessDesc) = try dummyPubkeyAndChecksumLessDesc(descriptor: nonRanged)
                let pkPrefixDesc = checksumlessDesc.string.replacingOccurrences(of: "tr(", with: "pk(")
                let descriptorString = "tr(\(dummyPubkey),and_v(v:\(pkPrefixDesc),after(\(timelock))))"
                #if DEBUG
                print("timelocked single sig taproot descriptorString: \(descriptorString)")
                #endif
                return try fetchTimelockAddressFromDescString(descriptorString: descriptorString, fnWallet: fnWallet)
                
            } else if fnDesc.isP2WPKH && !fnDesc.isMulti, let descriptor = descriptor {
                let processed = processSegwitSingleSigDescForMiniScript(desc: descriptor, index: keyIndex)
                let miniscript = "and_v(v:\(processed),after(\(timelock)))"
                let descriptorString = "wsh(\(miniscript))"
                #if DEBUG
                print("timelocked single sig segwit descriptorString: \(descriptorString)")
                #endif
                return try fetchTimelockAddressFromDescString(descriptorString: descriptorString, fnWallet: fnWallet)
                
            } else if fnDesc.isMulti && fnDesc.isP2WPKH {
                // Built from the address's own derived descriptor (explicit pubkeys), parsed
                // properly rather than by string replacement; fails rather than guesses.
                guard let derivedDescriptor, let descriptor else { throw TimelockedAddressError.unsupportedTimelockFormat }
                let processed = try multisigMiniscript(fromDerivedDescriptor: derivedDescriptor, parentDescriptor: descriptor, index: keyIndex)
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
    
    private func nonRanged(desc: String, index: UInt32 = 0) -> String {
        return desc.replacingOccurrences(of: "*", with: "\(index)")
    }
    
    private func processSegwitSingleSigDescForMiniScript(desc: String, index: UInt32) -> String {
        let checksumless = checkSumless(desc: desc)
        let nonRanged = nonRanged(desc: checksumless, index: index)
        let correctedNestedPrefix = nonRanged.replacingOccurrences(of: "wpkh(", with: "pk(")
        return correctedNestedPrefix
    }
    
    /// `multi(m,k1,k2,...)` for a miniscript. The ORDER of the keys comes from the address's derived
    /// descriptor (explicit pubkeys, sorted per BIP67 for `sortedmulti`, so every cosigner builds the
    /// identical script). The keys themselves are written as the wallet's own xpub expressions at
    /// `index`, because signing later needs the xpub to substitute the private key. Fails rather
    /// than guesses when the two descriptors can't be matched one-to-one by fingerprint.
    private func multisigMiniscript(fromDerivedDescriptor derived: String, parentDescriptor parent: String, index: UInt32) throws -> String {
        let derivedArgs = try multisigArguments(of: checkSumless(desc: derived))
        let parentArgs = try multisigArguments(of: checkSumless(desc: parent))
        guard derivedArgs.keys.count == parentArgs.keys.count, derivedArgs.threshold == parentArgs.threshold else {
            throw TimelockedAddressError.unsupportedTimelockFormat
        }
        
        func fingerprint(_ key: String) -> String? {
            guard key.hasPrefix("["), key.count > 9 else { return nil }
            return String(key.dropFirst().prefix(8)).lowercased()
        }
        
        var parentByFingerprint: [String: String] = [:]
        for key in parentArgs.keys {
            guard let fp = fingerprint(key), parentByFingerprint[fp] == nil else { throw TimelockedAddressError.unsupportedTimelockFormat }
            parentByFingerprint[fp] = key.replacingOccurrences(of: "*", with: "\(index)")
        }
        
        // Each derived key must be "[origin]<66 hex>" so it can be sorted, and match a parent key.
        var ordered: [(pubkey: String, expression: String)] = []
        for key in derivedArgs.keys {
            guard let range = key.range(of: "(0[23][0-9a-fA-F]{64})$", options: .regularExpression),
                  let fp = fingerprint(key), let expression = parentByFingerprint[fp] else {
                throw TimelockedAddressError.unsupportedTimelockFormat
            }
            ordered.append((String(key[range]).lowercased(), expression))
        }
        if derivedArgs.isSorted { ordered.sort { $0.pubkey < $1.pubkey } }
        
        return "multi(\(parentArgs.threshold),\(ordered.map { $0.expression }.joined(separator: ",")))"
    }
    
    /// Threshold, keys and whether it's `sortedmulti`, from a descriptor containing one multi().
    private func multisigArguments(of desc: String) throws -> (threshold: Int, keys: [String], isSorted: Bool) {
        let isSorted = desc.contains("sortedmulti(")
        guard let open = desc.range(of: isSorted ? "sortedmulti(" : "multi(")?.upperBound,
              let close = matchingParenthesis(in: desc, after: open) else {
            throw TimelockedAddressError.unsupportedTimelockFormat
        }
        let args = splitTopLevel(String(desc[open..<close]))
        guard args.count >= 3, let threshold = Int(args[0]), threshold >= 1, threshold <= args.count - 1 else {
            throw TimelockedAddressError.unsupportedTimelockFormat
        }
        return (threshold, Array(args.dropFirst()), isSorted)
    }
    
    /// Index of the ")" closing a "(" that sits just before `start`.
    private func matchingParenthesis(in string: String, after start: String.Index) -> String.Index? {
        var depth = 1
        var i = start
        while i < string.endIndex {
            if string[i] == "(" { depth += 1 }
            if string[i] == ")" { depth -= 1; if depth == 0 { return i } }
            i = string.index(after: i)
        }
        return nil
    }
    
    /// Splits on commas that aren't inside parentheses or brackets.
    private func splitTopLevel(_ string: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var depth = 0
        for character in string {
            if character == "(" || character == "[" { depth += 1 }
            if character == ")" || character == "]" { depth -= 1 }
            if character == "," && depth == 0 {
                parts.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        parts.append(current)
        return parts
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
    
    // Child pubkey (0/0) of the NUMS xpub from dummyKey(), so it's unspendable too.
    func dummyPubKey() throws -> String? {
        guard let dummyXpub = dummyKey() else {
            throw TimelockedAddressError.unableToGenerateDummyPubkey
        }
        
        guard let pk = Keys.childPubkey(xpub: dummyXpub) else {
            throw TimelockedAddressError.unableToGenerateDummyPubkey
        }
        return pk
    }
    
    
    func extractTimelockPolicyValues(from policyString: String?, hotXfp: String?) -> (topID: String?, subID: String?, timelock: UInt64?, hotFingerprint: String?) {
        guard let policyString,
              let jsonStart = policyString.range(of: "{")?.lowerBound,
              let jsonEnd = policyString.range(of: "}", options: .backwards)?.upperBound else {
            return (nil, nil, nil, nil)
        }
        
        let json = String(policyString[jsonStart..<jsonEnd])
        guard let data = json.data(using: .utf8) else {
            return (nil, nil, nil, nil)
        }
        
        do {
            guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return (nil, nil, nil, nil)
            }
            
            // Top-level THRESH (1-of-2 branches)
            let topID = jsonObject["id"] as? String
            
            guard let items = jsonObject["items"] as? [[String: Any]],
                  items.count == 2 else {
                return (topID, nil, nil, nil)
            }
            
            // Look for the inner THRESH (the one with MULTISIG + timelock)
            var subID: String?
            var timelockValue: UInt64?
            var hotFingerprint: String?
            
            for item in items {
                guard let itemType = item["type"] as? String,
                      itemType == "THRESH",
                      let itemID = item["id"] as? String,
                      let itemThreshold = item["threshold"] as? Int,
                      itemThreshold == 2,
                      let subItems = item["items"] as? [[String: Any]],
                      subItems.count == 2 else {
                    continue
                }
                
                subID = itemID
                
                // Now look inside this sub-THRESH's items
                for sub in subItems {
                    guard let subType = sub["type"] as? String else { continue }
                    
                    if subType == "MULTISIG",
                       let keys = sub["keys"] as? [[String: Any]] {
                        let fps = keys.compactMap({ $0["fingerprint"] as? String })
                        if let hotXfp = hotXfp,
                            fps.contains(hotXfp) {
                            hotFingerprint = hotXfp
                         }
                    }
                    else if subType == "ABSOLUTETIMELOCK",
                            let val = sub["value"] as? UInt64 {
                        timelockValue = val
                    }
                }
                
                // We found the interesting branch → can break early
                if subID != nil && (timelockValue != nil || hotFingerprint != nil) {
                    break
                }
            }
            
            return (topID, subID, timelockValue, hotFingerprint)
            
        } catch {
            #if DEBUG
            print("Policy JSON parse error: \(error)")
            #endif
            return (nil, nil, nil, nil)
        }
    }
    
    /// Only the silent payment address (sp1… / tsp1…) for a signer's seed, for display.
    /// The derived private keys stay inside WalletLogic.
    func silentPaymentAddress(mnemonic: String, passphrase: String?, mainnet: Bool) -> String? {
        let pass = (passphrase?.isEmpty ?? true) ? nil : passphrase
        return try? silentPaymentAddressFromMnemonic(mnemonic: mnemonic,
                                                     passphrase: pass,
                                                     network: mainnet ? .main : .test).address
    }
    
    /// The BIP352 scan private key (32-byte hex) for this seed, for exporting to a
    /// scanner such as Fully Noded Server. It can only detect incoming silent payments,
    /// never spend them. The spend private key derived alongside it is wiped here and
    /// never returned.
    func silentPaymentScanPrivateKey(mnemonic: String, passphrase: String?, mainnet: Bool) -> String? {
        let pass = (passphrase?.isEmpty ?? true) ? nil : passphrase
        guard var keys = try? silentPaymentAddressFromMnemonic(mnemonic: mnemonic,
                                                              passphrase: pass,
                                                              network: mainnet ? .main : .test) else { return nil }
        keys.spendPrivHex.secureWipe()
        return keys.scanPrivHex
    }
    
    //enum SilentPaymentFromMnemonic {
    func silentPaymentAddressFromMnemonic(
        mnemonic: String,
        passphrase: String? = nil,
        network: NetworkKind = .main
    ) throws -> (address: String, scanPrivHex: String, spendPrivHex: String, scanPubHex: String, spendPubHex: String) {
        let words = try Mnemonic.fromString(mnemonic: mnemonic)
        let master = DescriptorSecretKey(
            networkKind: network,
            mnemonic: words,
            password: passphrase
        )
        
        let spendPath = try BDKDerivationPath(path: SPSignerKeys.spendPath(mainnet: network == .main))
        let scanPath  = try BDKDerivationPath(path: SPSignerKeys.scanPath(mainnet: network == .main))
        
        let spendKey = try master.derive(path: spendPath)
        let scanKey  = try master.derive(path: scanPath)
        
        let spendPriv = Data(spendKey.secretBytes())
        let scanPriv  = Data(scanKey.secretBytes())
        
        let spendPub = Data(try P256K.Signing.PrivateKey(dataRepresentation: spendPriv).publicKey.dataRepresentation)
        let scanPub  = Data(try P256K.Signing.PrivateKey(dataRepresentation: scanPriv).publicKey.dataRepresentation)
        
        let hrp = (network == .main) ? "sp" : "tsp"
        let address = try Bech32m.encode(hrp: hrp, version: 0, data: scanPub + spendPub)
        
        return (
            address: address,
            scanPrivHex: SPHex.encode(scanPriv),
            spendPrivHex: SPHex.encode(spendPriv),
            scanPubHex: SPHex.encode(scanPub),
            spendPubHex: SPHex.encode(spendPub)
        )
    }
    //}
    
    enum SPHex {
        static func decode(_ hex: String) -> Data? {
            let s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "0x", with: "")
                .lowercased()
            guard s.count % 2 == 0 else { return nil }
            var data = Data()
            data.reserveCapacity(s.count / 2)
            var idx = s.startIndex
            while idx < s.endIndex {
                let next = s.index(idx, offsetBy: 2)
                guard let b = UInt8(s[idx..<next], radix: 16) else { return nil }
                data.append(b)
                idx = next
            }
            return data
        }

        static func encode(_ data: Data) -> String {
            data.map { String(format: "%02x", $0) }.joined()
        }

        static func reverse(_ hex: String) -> String? {
            guard let d = decode(hex) else { return nil }
            return encode(Data(d.reversed()))
        }
    }
    
    struct SPError: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }
    
    enum Bech32m {
        private static let charset = Array("qpzry9x8gf2tvdw0s3jn54khce6mua7l")
        private static let gen: [UInt32] = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]
        private static let const: UInt32 = 0x2bc830a3

        static func encode(hrp: String, version: Int, data: Data) throws -> String {
            var values = [UInt8(version)]
            values += try convertBits(Array(data), from: 8, to: 5, pad: true)
            let checksum = createChecksum(hrp: hrp, values: values)
            let combined = values + checksum
            return hrp + "1" + combined.map { String(charset[Int($0)]) }.joined()
        }

        static func decode(_ bech: String) throws -> (String, Int, Data) {
            let s = bech.lowercased()
            guard let pos = s.lastIndex(of: "1") else { throw SPError("bad bech32") }
            let hrp = String(s[s.startIndex..<pos])
            let dataPart = String(s[s.index(after: pos)...])
            var values: [UInt8] = []
            for ch in dataPart {
                guard let idx = charset.firstIndex(of: ch) else { throw SPError("bad bech32 char") }
                values.append(UInt8(charset.distance(from: charset.startIndex, to: idx)))
            }
            guard values.count >= 7, verifyChecksum(hrp: hrp, values: values) else {
                throw SPError("bad bech32 checksum")
            }
            let payload = Array(values.dropLast(6))
            guard let version = payload.first else { throw SPError("missing version") }
            let converted = try convertBits(Array(payload.dropFirst()), from: 5, to: 8, pad: false)
            return (hrp, Int(version), Data(converted))
        }

        private static func polymod(_ values: [UInt8]) -> UInt32 {
            var chk: UInt32 = 1
            for v in values {
                let b = chk >> 25
                chk = ((chk & 0x1ffffff) << 5) ^ UInt32(v)
                for i in 0..<5 where ((b >> i) & 1) != 0 {
                    chk ^= gen[i]
                }
            }
            return chk
        }

        private static func hrpExpand(_ hrp: String) -> [UInt8] {
            let bytes = Array(hrp.utf8)
            return bytes.map { $0 >> 5 } + [0] + bytes.map { $0 & 31 }
        }

        private static func createChecksum(hrp: String, values: [UInt8]) -> [UInt8] {
            let polymod = polymod(hrpExpand(hrp) + values + [0, 0, 0, 0, 0, 0]) ^ const
            return (0..<6).map { UInt8((polymod >> (5 * (5 - $0))) & 31) }
        }

        private static func verifyChecksum(hrp: String, values: [UInt8]) -> Bool {
            polymod(hrpExpand(hrp) + values) == const
        }

        private static func convertBits(_ data: [UInt8], from: Int, to: Int, pad: Bool) throws -> [UInt8] {
            var acc = 0, bits = 0, ret: [UInt8] = []
            let maxv = (1 << to) - 1
            for value in data {
                acc = (acc << from) | Int(value)
                bits += from
                while bits >= to {
                    bits -= to
                    ret.append(UInt8((acc >> bits) & maxv))
                }
            }
            if pad {
                if bits > 0 { ret.append(UInt8((acc << (to - bits)) & maxv)) }
            } else if bits >= from || ((acc << (to - bits)) & maxv) != 0 {
                throw SPError("invalid padding")
            }
            return ret
        }
    }
    
}

