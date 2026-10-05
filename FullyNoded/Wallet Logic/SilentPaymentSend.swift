//
//  SilentPaymentSend.swift
//  FullyNoded
//
//  Send BTC to a BIP352 silent payment address (sp1… / tsp1…) from the active wallet:
//  a normal Fully Noded wallet, or the watch-only wallet holding your received silent
//  payment outputs (those inputs' keys are b_spend + t_k, recomputed by detection).
//
//  WHY THIS ISN'T JUST walletcreatefundedpsbt(outputs: [sp1…: amount])
//  --------------------------------------------------------------------
//  An SP address isn't a scriptPubKey. The actual output key depends on the exact
//  inputs of the tx and on the SENDER'S input private keys:
//
//    a          = Σ a_i  (private keys of the eligible inputs; a P2TR input uses its
//                        tweaked output key, negated if that key has odd Y)
//    A          = a·G
//    input_hash = hash_BIP0352/Inputs(smallest_outpoint || A)
//    ecdh       = (input_hash · a) · B_scan
//    t_0        = hash_BIP0352/SharedSecret(ecdh || ser32(0))
//    P          = B_spend + t_0·G   →  output = P2TR(xonly(P))
//
//  So the flow is:
//    1. walletcreatefundedpsbt with a same-size PLACEHOLDER P2TR output (Core
//       picks inputs, change and fee exactly as it would for the real output).
//    2. decodepsbt → the chosen inputs, their prevout scripts and BIP32 paths.
//    3. Derive each input's private key from your Fully Noded signer, checking it
//       against the pubkey / scriptPubKey in the PSBT. Inputs that are your own
//       silent payment outputs are found by detection (as in the verifier) and use
//       b_spend + t_k (+ label). The keys are used ONLY to compute the output, then
//       wiped. Nothing is signed here.
//    4. Compute P and its P2TR address (and, if asked, silent payment change: k = 0,
//       or k = 1 when you're paying your own silent payment address).
//    5. Rebuild with createpsbt: EXACTLY the same inputs and amounts (so the same
//       fee), placeholder(s) replaced, then verify (otherwise P would be wrong).
//    6. Return the UNSIGNED psbt. CreateRawTxViewController passes it to
//       VerifyTransactionViewController, where the normal sign/broadcast flow runs.
//
//  ⚠️ After this, the tx must keep EXACTLY these inputs. Signing is fine, but
//  bumping the fee with extra inputs (or coin-control changes) would make the
//  silent payment output unspendable by the recipient, so rebuild instead.
//
//  Supported inputs (BIP352): wpkh, sh(wpkh), pkh and tr, plus your received silent
//  payment outputs. Taproot inputs use the OUTPUT key's private key (internal key
//  tweaked with the script tree's merkle root, if any) whichever path they're spent
//  by; taproot inputs whose internal key is the NUMS point H are skipped (no key,
//  outpoint still counts). Other inputs (e.g. wsh multisig) aren't eligible: they're
//  allowed but add no key, and at least one eligible input is required.
//

import Foundation
import CryptoKit
import BitcoinDevKit
import P256K

enum SilentPaymentSend {

    // True for sp1… (mainnet) / tsp1… (test networks) addresses.
    static func isSilentPaymentAddress(_ address: String) -> Bool {
        let a = address.replacingOccurrences(of: "-", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return a.hasPrefix("sp1") || a.hasPrefix("tsp1")
    }

    /// Build an UNSIGNED psbt paying `amount` (BTC, e.g. "0.0001") to `spAddress`
    /// from the active Fully Noded wallet.
    /// - Parameters:
    ///   - inputs: optional coin-control inputs ([["txid": …, "vout": …]]), same format
    ///     as CreatePSBT. Empty lets Core choose.
    ///   - passphrase: signer passphrase, if any. The signer's stored passphrase and no
    ///     passphrase are tried too.
    ///   - change: where the change goes. `.wallet` (default) lets Core pick the wallet's
    ///     own change address; `.silentPayment` sends it to your silent payment change
    ///     address (offered when silent payment outputs are spent).
    /// - Returns: (psbt, errorMessage), always on the main queue.
    static func create(spAddress: String,
                       amount: String,
                       inputs: [[String: Any]] = [],
                       passphrase: String? = nil,
                       change: SilentPaymentChange.Destination = .wallet,
                       completion: @escaping (_ psbt: String?, _ errorMessage: String?) -> Void) {

        // Always report back on the main queue (callers update UI).
        let done: (String?, String?) -> Void = { psbt, error in
            DispatchQueue.main.async { completion(psbt, error) }
        }

        // 1. Parse the SP address → B_scan, B_spend.
        let recipient: SPRecipient
        do {
            recipient = try SPRecipient(address: spAddress.replacingOccurrences(of: "-", with: ""))
        } catch {
            done(nil, error.localizedDescription)
            return
        }

        // 2. Placeholder P2TR output of the same size as the real one. B_spend's x
        //    coordinate is used only so the address is well-formed. This PSBT is
        //    never signed or broadcast.
        guard let placeholder = try? SPAddress.p2tr(xonly: recipient.spendPub.dropFirst()) else {
            done(nil, "Unable to build placeholder output.")
            return
        }

        // Change: Core's own, an explicit address, or a placeholder for silent payment
        // change (replaced in step 5).
        let changeAddress: String?
        switch change {
        case .wallet:
            changeAddress = nil
        case .silentPayment:
            guard let p = SilentPaymentChange.placeholderAddress() else {
                done(nil, "Unable to build the placeholder change output.")
                return
            }
            changeAddress = p
        }
        let recipientPlaceholderScript = "5120" + SPHexFN.encode(recipient.spendPub.dropFirst())

        CreatePSBT.create(inputs: inputs, outputs: [[placeholder: amount]], changeAddress: changeAddress) { firstPsbt, _, errorMessage in
            guard let firstPsbt = firstPsbt else {
                done(nil, errorMessage ?? "walletcreatefundedpsbt failed.")
                return
            }

            // 3. Inspect the inputs Core chose.
            SilentPaymentSend.decode(firstPsbt) { decoded, error in
                guard let decoded = decoded else {
                    done(nil, error ?? "decodepsbt failed.")
                    return
                }

                // Which inputs are your own silent payment outputs (their keys are
                // b_spend + t_k, which has no BIP32 path in the PSBT).
                SilentPaymentSpend.detectInputs(psbt: firstPsbt, passphrase: passphrase) { owned in

                    // 4. Derive the private keys for those inputs from the stored signers.
                    SPInputKeys.derive(for: decoded.inputs, passphrase: passphrase, silentPaymentOutputs: owned) { keys, error in
                        guard var keys = keys else {
                            done(nil, error ?? "Unable to derive input keys.")
                            return
                        }

                        // 5. Compute the silent payment output, then wipe the keys.
                        let outputAddress: String
                        let outputXonly: String
                        do {
                            defer {
                                for i in keys.indices { keys[i].secret.secureZero() }
                                keys.removeAll()
                            }
                            let xonly = try SPSender.outputKey(inputKeys: keys,
                                                               outpoints: decoded.inputs.map { $0.outpoint },
                                                               recipient: recipient)
                            outputXonly = SPHexFN.encode(xonly)
                            outputAddress = try SPAddress.p2tr(xonly: xonly)
                        } catch {
                            done(nil, error.localizedDescription)
                            return
                        }

                        #if DEBUG
                        print("SP output key: \(outputXonly) address: \(outputAddress)")
                        #endif

                        // 6. Rebuild with EXACTLY the same inputs and amounts, real output(s).
                        SilentPaymentChange.decode(firstPsbt) { tx, error in
                            guard let tx = tx,
                                  let recipientIndex = tx.outputs.firstIndex(where: { $0.script == recipientPlaceholderScript }) else {
                                done(nil, error ?? "Placeholder output not found. Aborted.")
                                return
                            }
                            var replacing: [Int: (address: String, script: String)] = [
                                recipientIndex: (outputAddress, "5120" + outputXonly)
                            ]

                            let changeIndex = tx.outputs.firstIndex(where: { $0.script == SilentPaymentChange.placeholderScript })
                            guard case .silentPayment = change, let changeIndex = changeIndex else {
                                SilentPaymentChange.rebuild(tx: tx, replacing: replacing, completion: done)
                                return
                            }

                            // Silent payment change (label 0 of the signer owning the inputs).
                            SilentPaymentChange.change(for: tx,
                                                       changeIndex: changeIndex,
                                                       passphrase: passphrase,
                                                       recipientScanPub: recipient.scanPub,
                                                       finalScripts: [recipientIndex: "5120" + outputXonly]) { address, script, error in
                                guard let address = address, let script = script else {
                                    done(nil, error)
                                    return
                                }
                                replacing[changeIndex] = (address, script)
                                SilentPaymentChange.rebuild(tx: tx, replacing: replacing, completion: done)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - decodepsbt → what we need

    // One PSBT input, as far as BIP352 is concerned.
    struct DecodedInput {
        let txid: String
        let vout: Int
        // Prevout scriptPubKey hex (from witness_utxo or non_witness_utxo).
        let scriptPubKey: String
        // Prevout address (informational).
        let address: String?
        // Redeem script hex for P2SH inputs.
        let redeemScript: String?
        // BIP32 derivations: (pubkey hex, path). For taproot the pubkey is x-only.
        let derivations: [(pubkey: String, path: String)]
        // Taproot: derivations of the INTERNAL key only (no leaf hashes); keys that only
        // appear in leaf scripts are excluded, since BIP352 uses the output key.
        let tapInternalDerivations: [(pubkey: String, path: String)]
        // Taproot internal key (x-only hex) and script tree merkle root, if any.
        let tapInternalKey: String?
        let tapMerkleRoot: String?

        // 36-byte serialized outpoint: txid (internal byte order) || vout LE.
        var outpoint: Data {
            var d = Data((SPHexFN.decode(txid) ?? Data()).reversed())
            var le = UInt32(vout).littleEndian
            d.append(Data(bytes: &le, count: 4))
            return d
        }
    }

    struct DecodedPsbt {
        let inputs: [DecodedInput]
        // scriptPubKey hex of every output.
        let outputScripts: [String]
    }

    // decodepsbt and pull out inputs/outputs.
    private static func decode(_ psbt: String, completion: @escaping (DecodedPsbt?, String?) -> Void) {
        let param = Decode_Psbt(["psbt": psbt])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .decodepsbt(param: param)) { response, errorDesc in
            guard let dict = response as? [String: Any],
                  let tx = dict["tx"] as? [String: Any],
                  let vin = tx["vin"] as? [[String: Any]],
                  let vout = tx["vout"] as? [[String: Any]],
                  let psbtInputs = dict["inputs"] as? [[String: Any]],
                  psbtInputs.count == vin.count
            else {
                completion(nil, errorDesc ?? "Unexpected decodepsbt response.")
                return
            }

            var inputs: [DecodedInput] = []
            for (i, txin) in vin.enumerated() {
                guard let txid = txin["txid"] as? String,
                      let n = (txin["vout"] as? NSNumber)?.intValue else {
                    completion(nil, "Input \(i) has no txid/vout.")
                    return
                }
                let pin = psbtInputs[i]

                // Prevout script: witness_utxo (segwit) or non_witness_utxo.vout[n] (legacy).
                var spk: [String: Any]?
                if let wu = pin["witness_utxo"] as? [String: Any] {
                    spk = wu["scriptPubKey"] as? [String: Any]
                } else if let nwu = pin["non_witness_utxo"] as? [String: Any],
                          let outs = nwu["vout"] as? [[String: Any]], n < outs.count {
                    spk = outs[n]["scriptPubKey"] as? [String: Any]
                }
                guard let spkHex = (spk?["hex"] as? String)?.lowercased() else {
                    completion(nil, "Input \(i) has no prevout script in the PSBT.")
                    return
                }

                // Derivations (segwit v0 / legacy and taproot are listed separately).
                var derivs: [(pubkey: String, path: String)] = []
                for d in pin["bip32_derivs"] as? [[String: Any]] ?? [] {
                    if let pk = d["pubkey"] as? String, let path = d["path"] as? String {
                        derivs.append((pk.lowercased(), path))
                    }
                }
                var tapInternal: [(pubkey: String, path: String)] = []
                let internalKey = (pin["taproot_internal_key"] as? String)?.lowercased()
                for d in pin["taproot_bip32_derivs"] as? [[String: Any]] ?? [] {
                    guard let pk = (d["pubkey"] as? String)?.lowercased(), let path = d["path"] as? String else { continue }
                    derivs.append((pk, path))
                    let leaves = d["leaf_hashes"] as? [Any] ?? []
                    // The internal key: no leaf hashes, and it matches the PSBT's internal
                    // key field when present.
                    if leaves.isEmpty && (internalKey == nil || internalKey == pk) {
                        tapInternal.append((pk, path))
                    }
                }

                inputs.append(DecodedInput(
                    txid: txid,
                    vout: n,
                    scriptPubKey: spkHex,
                    address: spk?["address"] as? String,
                    redeemScript: ((pin["redeem_script"] as? [String: Any])?["hex"] as? String)?.lowercased(),
                    derivations: derivs,
                    tapInternalDerivations: tapInternal,
                    tapInternalKey: internalKey,
                    tapMerkleRoot: (pin["taproot_merkle_root"] as? String)?.lowercased()
                ))
            }

            let outputs = vout.compactMap { (($0["scriptPubKey"] as? [String: Any])?["hex"] as? String)?.lowercased() }
            completion(DecodedPsbt(inputs: inputs, outputScripts: outputs), nil)
        }
    }

}


// MARK: - Recipient (SP address)

// B_scan and B_spend from an sp1… / tsp1… address.
struct SPRecipient {
    let scanPub: Data   // 33 bytes compressed
    let spendPub: Data  // 33 bytes compressed

    init(address: String) throws {
        let (hrp, version, data) = try WalletLogic.Bech32m.decode(address.trimmingCharacters(in: .whitespacesAndNewlines))

        // Network must match the node: "sp" on mainnet, "tsp" on test networks.
        let expectedHrp = SPAddress.isMainnet ? "sp" : "tsp"
        guard hrp == expectedHrp else {
            throw WalletLogic.SPError("This is a \(hrp) address, but the node is on \(SPAddress.chain). Expected \(expectedHrp)1….")
        }
        // BIP352: v0 is exactly 66 bytes; v1–v30 are read forward-compatibly (first
        // 66 bytes); v31 is reserved for breaking changes.
        guard version != 31 else { throw WalletLogic.SPError("Unsupported silent payment address version 31.") }
        guard (version == 0 && data.count == 66) || (version > 0 && data.count >= 66) else {
            throw WalletLogic.SPError("Invalid silent payment address length.")
        }
        let scan = Data(data.prefix(33))
        let spend = Data(data.dropFirst(33).prefix(33))
        // Both must be valid curve points.
        _ = try P256K.Signing.PublicKey(dataRepresentation: scan, format: .compressed)
        _ = try P256K.Signing.PublicKey(dataRepresentation: spend, format: .compressed)
        scanPub = scan
        spendPub = spend
    }
}


// MARK: - Addresses

enum SPAddress {
    // Same "chain" setting WalletLogic.bdkNetwork() uses.
    static var chain: String { UserDefaults.standard.object(forKey: "chain") as? String ?? "main" }
    static var isMainnet: Bool { chain == "main" }

    // Segwit HRP for the active chain.
    static var segwitHrp: String {
        switch chain {
        case "main": return "bc"
        case "regtest": return "bcrt"
        default: return "tb"      // test, testnet4, signet
        }
    }

    // bech32m P2TR address (witness v1) for a 32-byte x-only key.
    static func p2tr<D: DataProtocol>(xonly: D) throws -> String {
        let key = Data(xonly)
        guard key.count == 32 else { throw WalletLogic.SPError("x-only key must be 32 bytes") }
        return try WalletLogic.Bech32m.encode(hrp: segwitHrp, version: 1, data: key)
    }
}


// MARK: - Input private keys

enum SPInputKeys {

    // One eligible input's private key a_i, already adjusted per BIP352 (for P2TR:
    // tweaked, and negated if the output key has odd Y).
    struct Key {
        var secret: Data
    }

    enum Kind { case p2pkh, p2wpkh, p2shP2wpkh, p2tr, ineligible }

    // Classify an input by its prevout script.
    static func kind(of input: SilentPaymentSend.DecodedInput) throws -> Kind {
        let s = input.scriptPubKey
        // Witness programs v2–v16 make the whole tx ineligible (BIP352).
        if SPDetect.isSegwitV2Plus(s) {
            throw WalletLogic.SPError("An input spends a segwit v2+ output; silent payments can't be used with this input.")
        }
        if SPDetect.isP2TR(s) {
            // Internal key = NUMS point H: it can only be spent via a script path and
            // BIP352 skips it (adds no key; its outpoint still counts).
            if input.tapInternalKey == SPDetect.numsH { return .ineligible }
            return .p2tr
        }
        if SPDetect.isP2WPKH(s) { return .p2wpkh }
        if SPDetect.isP2PKH(s) { return .p2pkh }
        if SPDetect.isP2SH(s), let rs = input.redeemScript, SPDetect.isP2WPKH(rs) {
            return .p2shP2wpkh
        }
        return .ineligible
    }

    /// Derive a_i for every eligible input using the stored Fully Noded signers.
    /// Tries the passed passphrase, then each signer's stored passphrase, then none.
    /// A key is only accepted if it reproduces the pubkey/scriptPubKey in the PSBT.
    /// - silentPaymentOutputs: inputs that are your own silent payment outputs (from
    ///   `SilentPaymentSpend.detectInputs`); their key is b_spend + t_k (+ label_m).
    static func derive(for inputs: [SilentPaymentSend.DecodedInput],
                       passphrase: String?,
                       silentPaymentOutputs: [SilentPaymentSpend.OwnedOutput] = [],
                       completion: @escaping ([Key]?, String?) -> Void) {

        CoreDataService.retrieveEntity(entityName: .signers) { signers in
            guard let signers = signers, !signers.isEmpty else {
                completion(nil, "No signers.")
                return
            }

            // Master keys for every signer / passphrase candidate, built once.
            let masters = SPSignerKeys.masters(signers: signers, passphrase: passphrase)

            var keys: [Key] = []
            do {
                for (i, input) in inputs.enumerated() {
                    let kind = try SPInputKeys.kind(of: input)
                    guard kind != .ineligible else { continue }   // adds its outpoint only
                    // Your own silent payment output: b_spend + t_k (+ label_m).
                    if kind == .p2tr,
                       let owned = silentPaymentOutputs.first(where: { $0.txid.lowercased() == input.txid.lowercased() && $0.vout == input.vout }) {
                        guard let key = SPInputKeys.silentPaymentKey(input: input, owned: owned, masters: masters) else {
                            throw WalletLogic.SPError("Input \(i) is a silent payment output but none of your signers can produce its key.")
                        }
                        keys.append(key)
                        continue
                    }
                    guard let key = try SPInputKeys.deriveKey(input: input, kind: kind, masters: masters) else {
                        throw WalletLogic.SPError("None of your signers can produce the key for input \(i) (\(input.txid):\(input.vout)). Silent payments need the private key of every eligible input (for taproot, of its output key).")
                    }
                    keys.append(key)
                }
            } catch {
                completion(nil, error.localizedDescription)
                return
            }

            guard !keys.isEmpty else {
                completion(nil, "No eligible inputs (wpkh, sh-wpkh, pkh or taproot key path) were selected.")
                return
            }
            completion(keys, nil)
        }
    }

    /// a_i for one of your received silent payment outputs: d = b_spend + t_k (+ label_m),
    /// accepted only if d·G is the input's output key, negated if it has odd Y (BIP352
    /// uses the even-Y key for taproot inputs).
    static func silentPaymentKey(input: SilentPaymentSend.DecodedInput,
                                 owned: SilentPaymentSpend.OwnedOutput,
                                 masters: [DescriptorSecretKey]) -> Key? {
        guard let tweak = SPHexFN.decode(owned.tweakHex), tweak.count == 32, SPScalar.isValid(tweak) else { return nil }
        var label: Data?
        if let labelHex = owned.labelTweakHex {
            guard let l = SPHexFN.decode(labelHex), l.count == 32, SPScalar.isValid(l) else { return nil }
            label = l
        }
        guard let path = try? BDKDerivationPathFN(path: SPSignerKeys.spendPath()) else { return nil }

        for master in masters {
            guard let child = try? master.derive(path: path) else { continue }
            var bSpend = Data(child.secretBytes())
            var d = SPScalar.add(bSpend, tweak)
            bSpend.secureZero()
            if let label = label { d = SPScalar.add(d, label) }

            guard let priv = try? P256K.Signing.PrivateKey(dataRepresentation: d) else {
                d.secureZero()
                continue
            }
            let pub = Data(priv.publicKey.dataRepresentation)
            guard "5120" + SPHexFN.encode(pub.dropFirst()) == input.scriptPubKey.lowercased() else {
                d.secureZero()   // another signer / passphrase
                continue
            }
            if pub.first == 0x03 { d = SPScalar.negate(d) }
            return Key(secret: d)
        }
        return nil
    }

    // Find the derivation that one of our masters can reproduce, and return a_i.
    private static func deriveKey(input: SilentPaymentSend.DecodedInput,
                                  kind: Kind,
                                  masters: [DescriptorSecretKey]) throws -> Key? {
        // Taproot: only the internal key leads to the output key (BIP352 uses the output
        // key's private key whether the input is later spent via key or script path).
        let candidates = kind == .p2tr ? input.tapInternalDerivations : input.derivations
        for deriv in candidates {
            guard let path = try? BDKDerivationPathFN(path: deriv.path) else { continue }
            for master in masters {
                guard let child = try? master.derive(path: path) else { continue }
                var secret = Data(child.secretBytes())
                guard let priv = try? P256K.Signing.PrivateKey(dataRepresentation: secret) else {
                    secret.secureZero()
                    continue
                }
                let pub = Data(priv.publicKey.dataRepresentation)   // 33-byte compressed

                switch kind {
                case .p2wpkh, .p2shP2wpkh, .p2pkh:
                    // PSBT lists the compressed pubkey; it must match exactly.
                    if SPHexFN.encode(pub) == deriv.pubkey {
                        return Key(secret: secret)
                    }

                case .p2tr:
                    // PSBT lists the x-only INTERNAL key.
                    guard SPHexFN.encode(pub.dropFirst()) == deriv.pubkey else { break }
                    // BIP341 output key tweak:
                    //   d  = internal key, negated if P = d·G has odd Y
                    //   t  = hash_TapTweak(xonly(P) [|| merkle_root])   (root only with a script tree)
                    //   q  = d + t, negated if Q = q·G has odd Y (BIP352 needs even Y)
                    var d = secret
                    if pub.first == 0x03 { d = SPScalar.negate(d) }
                    var tweakData = Data(pub.dropFirst())
                    if let rootHex = input.tapMerkleRoot {
                        guard let root = SPHexFN.decode(rootHex), root.count == 32 else {
                            throw WalletLogic.SPError("Invalid taproot merkle root for input \(input.txid):\(input.vout).")
                        }
                        tweakData += root
                    }
                    let t = SPHashFN.tagged("TapTweak", tweakData)
                    guard SPScalar.isValid(t) else { throw WalletLogic.SPError("Invalid taproot tweak.") }
                    var q = SPScalar.add(d, t)
                    guard let qPriv = try? P256K.Signing.PrivateKey(dataRepresentation: q) else {
                        throw WalletLogic.SPError("Invalid tweaked taproot key.")
                    }
                    let qPub = Data(qPriv.publicKey.dataRepresentation)
                    if qPub.first == 0x03 { q = SPScalar.negate(q) }
                    // Safety: the tweaked key must be the output key in the prevout script.
                    guard "5120" + SPHexFN.encode(qPub.dropFirst()) == input.scriptPubKey else {
                        throw WalletLogic.SPError("Derived taproot key doesn't match input \(input.txid):\(input.vout). The PSBT may be missing the input's taproot merkle root.")
                    }
                    secret.secureZero()
                    return Key(secret: q)

                case .ineligible:
                    break
                }
                secret.secureZero()
            }
        }
        return nil
    }
}

// BitcoinDevKit.DerivationPath, named so it doesn't clash with other types.
typealias BDKDerivationPathFN = BitcoinDevKit.DerivationPath


// MARK: - Sender math (BIP352)

enum SPSender {
    /// x-only output key for a single silent payment output (k = 0).
    static func outputKey(inputKeys: [SPInputKeys.Key],
                          outpoints: [Data],
                          recipient: SPRecipient) throws -> Data {
        // a = Σ a_i mod n.
        var a = Data(count: 32)
        for k in inputKeys { a = SPScalar.add(a, k.secret) }
        defer { a.secureZero() }
        guard !SPScalar.isZero(a) else { throw WalletLogic.SPError("Input keys sum to zero; can't create a silent payment with these inputs.") }

        // A = a·G (compressed).
        let aPriv = try P256K.Signing.PrivateKey(dataRepresentation: a)
        let A = Data(aPriv.publicKey.dataRepresentation)

        // Smallest outpoint (lexicographic over the 36-byte serialization, ALL inputs).
        guard let smallest = outpoints.min(by: { $0.lexicographicallyPrecedes($1) }) else {
            throw WalletLogic.SPError("No inputs.")
        }

        // input_hash = hash_BIP0352/Inputs(outpoint_L || A).
        let inputHash = SPHashFN.tagged("BIP0352/Inputs", smallest + A)
        guard SPScalar.isValid(inputHash) else { throw WalletLogic.SPError("Invalid input hash.") }

        // ecdh = input_hash · a · B_scan (two tweak-multiplies on the point).
        let bScan = try P256K.Signing.PublicKey(dataRepresentation: recipient.scanPub, format: .compressed)
        let ecdh = try bScan.multiply(Array(a), format: .compressed)
                            .multiply(Array(inputHash), format: .compressed)

        // t_0 = hash_BIP0352/SharedSecret(serP(ecdh) || ser32(0)).
        let t0 = SPHashFN.tagged("BIP0352/SharedSecret", Data(ecdh.dataRepresentation) + Data([0, 0, 0, 0]))
        guard SPScalar.isValid(t0) else { throw WalletLogic.SPError("Invalid shared secret tweak.") }

        // P = B_spend + t_0·G.
        let bSpend = try P256K.Signing.PublicKey(dataRepresentation: recipient.spendPub, format: .compressed)
        let p = try bSpend.add(Array(t0))
        return Data(p.xonly.bytes)
    }
}


// MARK: - Scalar math mod n (secp256k1 group order)

// Minimal 256-bit arithmetic for summing / negating private keys. Scalars are
// 32-byte big-endian Data; limbs are big-endian [UInt64] (index 0 = most significant).
enum SPScalar {
    static let n: [UInt64] = [0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFE, 0xBAAEDCE6AF48A03B, 0xBFD25E8CD0364141]

    static func limbs(_ d: Data) -> [UInt64] {
        let b = [UInt8](d)
        precondition(b.count == 32)
        return (0..<4).map { i in b[(i * 8)..<(i * 8 + 8)].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) } }
    }

    static func data(_ l: [UInt64]) -> Data {
        var out = Data(capacity: 32)
        for limb in l { for s in stride(from: 56, through: 0, by: -8) { out.append(UInt8(truncatingIfNeeded: limb >> UInt64(s))) } }
        return out
    }

    // -1, 0, 1 like a <=> b.
    static func compare(_ a: [UInt64], _ b: [UInt64]) -> Int {
        for i in 0..<4 where a[i] != b[i] { return a[i] < b[i] ? -1 : 1 }
        return 0
    }

    // a - b with wrap-around (mod 2^256).
    static func sub(_ a: [UInt64], _ b: [UInt64]) -> [UInt64] {
        var r = [UInt64](repeating: 0, count: 4)
        var borrow: UInt64 = 0
        for i in stride(from: 3, through: 0, by: -1) {
            let (d1, o1) = a[i].subtractingReportingOverflow(b[i])
            let (d2, o2) = d1.subtractingReportingOverflow(borrow)
            r[i] = d2
            borrow = (o1 ? 1 : 0) + (o2 ? 1 : 0)
        }
        return r
    }

    // (a + b) mod n, for a, b < n.
    static func add(_ a: Data, _ b: Data) -> Data {
        let x = limbs(a), y = limbs(b)
        var r = [UInt64](repeating: 0, count: 4)
        var carry: UInt64 = 0
        for i in stride(from: 3, through: 0, by: -1) {
            let (s1, o1) = x[i].addingReportingOverflow(y[i])
            let (s2, o2) = s1.addingReportingOverflow(carry)
            r[i] = s2
            carry = (o1 ? 1 : 0) + (o2 ? 1 : 0)
        }
        // If it overflowed 2^256 or is ≥ n, subtract n once (the wrap-around
        // subtraction gives the right result in the overflow case too).
        if carry == 1 || compare(r, n) >= 0 { r = sub(r, n) }
        return data(r)
    }

    // (n - a) mod n.
    static func negate(_ a: Data) -> Data {
        isZero(a) ? a : data(sub(n, limbs(a)))
    }

    static func isZero(_ a: Data) -> Bool { a.allSatisfy { $0 == 0 } }

    // 0 < a < n (valid private key / tweak).
    static func isValid(_ a: Data) -> Bool { a.count == 32 && !isZero(a) && compare(limbs(a), n) < 0 }
}


// MARK: - Hash / hex helpers (FN-local names so they don't clash with WalletLogic.SPHex)

enum SPHashFN {
    // BIP340 tagged hash.
    static func tagged(_ tag: String, _ msg: Data) -> Data {
        let t = Data(SHA256.hash(data: Data(tag.utf8)))
        return Data(SHA256.hash(data: t + t + msg))
    }

    /// HASH160 = RIPEMD160(SHA256(data)).
    static func hash160(_ data: Data) -> Data {
        SPRIPEMD160.hash(Data(SHA256.hash(data: data)))
    }
}

enum SPHexFN {
    static func decode(_ hex: String) -> Data? { WalletLogic.SPHex.decode(hex) }
    static func encode<D: DataProtocol>(_ d: D) -> String { WalletLogic.SPHex.encode(Data(d)) }
}

/*
 Usage: CreateRawTxViewController.getRawTx() routes a single sp1…/tsp1… recipient here
 and passes the returned psbt to VerifyTransactionViewController (unsignedPsbt),
 where it is signed and broadcast like any other transaction.

 SilentPaymentSend.create(spAddress: "tsp1q…", amount: "0.0001") { psbt, error in
     // psbt is unsigned
 }
*/
