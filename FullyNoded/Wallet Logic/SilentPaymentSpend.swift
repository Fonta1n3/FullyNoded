//
//  SilentPaymentSpend.swift
//  FullyNoded
//
//  Sign BIP352 silent payment INPUTS (outputs you received to your sp1… address)
//  in a PSBT, using tweaked-key signing.
//
//  A received silent payment output is a P2TR output whose key is used as-is
//  (FN-Server imports it as rawtr(<xonly>), no BIP341 taproot tweak):
//
//    P = B_spend + t_k·G (+ label_m·G)
//
//  so its private key is:
//
//    d = b_spend + t_k (+ label_m)  mod n
//    d = n - d  if d·G has odd Y            (BIP340 signs for the even-Y key)
//
//  and the input is spent with a BIP340 Schnorr key-path signature over the
//  BIP341 sighash, written to the PSBT as PSBT_IN_TAP_KEY_SIG (BIP371, key 0x13).
//
//  WHERE THE PIECES COME FROM
//  --------------------------
//  * b_spend: derived from your Fully Noded signer at m/352'/coin'/0'/0'/0 (same
//    path as WalletLogic.silentPaymentAddressFromMnemonic).
//  * t_k / label_m: per output, NOT derivable from the seed alone. FN-Server's
//    scanner saves them (SPFoundOutput.tweakHex / labelTweakHex). OwnedOutput
//    decodes that JSON directly.
//
//  SAFETY
//  ------
//  * An input is only signed if its outpoint is in `outputs` AND d·G reproduces
//    the exact P2TR scriptPubKey of that input in the PSBT.
//  * Each signature is verified against the output key before it is added.
//  * The BIP341 sighash commits to the amounts and scriptPubKeys of ALL inputs,
//    so a PSBT that lies about any prevout produces an invalid signature rather
//    than a fee-overpaying one.
//  * Only SIGHASH_DEFAULT (0x00) and SIGHASH_ALL (0x01) are supported.
//  * d is wiped after use. Nothing is broadcast here.
//
//  The returned PSBT still needs finalizing (e.g. Core's finalizepsbt, which
//  turns a PSBT_IN_TAP_KEY_SIG into the key-path witness), plus signatures for
//  any non-SP inputs from the normal Signer.
//

import Foundation
import CryptoKit
import BitcoinDevKit
import P256K

enum SilentPaymentSpend {

    // One silent payment output you own. Field names match FN-Server's
    // SPFoundOutput, so its saved "found" array decodes as [OwnedOutput].
    struct OwnedOutput: Decodable {
        // Txid of the paying transaction (RPC display order).
        let txid: String
        let vout: Int
        // t_k (hex).
        let tweakHex: String
        // label_m (hex), only for outputs paid to a labeled address.
        let labelTweakHex: String?
    }

    /// Sign every silent payment input of `psbt` that appears in `outputs`, deriving
    /// b_spend from the stored Fully Noded signers.
    /// - Parameters:
    ///   - passphrase: signer passphrase, if any. The signer's stored passphrase and
    ///     no passphrase are tried too; the right one is whichever reproduces the
    ///     input's output key.
    /// - Returns: (signed psbt, number of inputs signed, errorMessage), on the main queue.
    static func sign(psbt: String,
                     outputs: [OwnedOutput],
                     passphrase: String? = nil,
                     completion: @escaping (_ psbt: String?, _ signed: Int, _ errorMessage: String?) -> Void) {

        let done: (String?, Int, String?) -> Void = { psbt, count, error in
            DispatchQueue.main.async { completion(psbt, count, error) }
        }

        CoreDataService.retrieveEntity(entityName: .signers) { signers in
            guard let signers = signers, !signers.isEmpty else {
                done(nil, 0, "No signers.")
                return
            }

            var lastError: String?
            var finished = false
            // Every signer / passphrase candidate (typed, stored, none) until one works.
            SPSignerKeys.forEachMaster(signers: signers, passphrase: passphrase) { _, master in
                guard var bSpend = spendKey(master: master) else { return false }
                defer { bSpend.secureZero() }
                do {
                    let result = try sign(psbt: psbt, outputs: outputs, spendKey: bSpend)
                    done(result.psbt, result.signed, nil)
                    finished = true
                    return true
                } catch let error as KeyMismatch {
                    // Wrong signer / passphrase: try the next one.
                    lastError = error.localizedDescription
                    return false
                } catch {
                    // A problem with the PSBT itself: no other key will fix it.
                    done(nil, 0, error.localizedDescription)
                    finished = true
                    return true
                }
            }
            guard !finished else { return }
            done(nil, 0, lastError ?? "None of your signers can sign these silent payment inputs.")
        }
    }

    /// Sign with an explicit b_spend (32 bytes). Throws if no input could be signed.
    /// Pure function: no Core Data, no RPC.
    static func sign(psbt base64: String,
                     outputs: [OwnedOutput],
                     spendKey bSpend: Data) throws -> (psbt: String, signed: Int) {

        guard SPScalar.isValid(bSpend) else { throw WalletLogic.SPError("Invalid spend private key.") }
        guard let raw = Data(base64Encoded: base64.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw WalletLogic.SPError("PSBT is not valid base64.")
        }
        var psbt = try SPPsbt(raw)
        let tx = psbt.tx

        // outpoint "txid:vout" → owned output.
        var owned: [String: OwnedOutput] = [:]
        for o in outputs { owned["\(o.txid.lowercased()):\(o.vout)"] = o }

        // Prevouts of every input (BIP341 needs all of them).
        var prevouts: [SPTx.Output] = []
        for i in tx.inputs.indices { prevouts.append(try psbt.prevout(input: i)) }

        var signed = 0
        var mismatches: [String] = []

        for (i, input) in tx.inputs.enumerated() {
            guard let out = owned["\(input.txidDisplay):\(input.vout)"] else { continue }
            let spk = prevouts[i].script
            guard spk.count == 34, spk[spk.startIndex] == 0x51, spk[spk.startIndex + 1] == 0x20 else {
                throw WalletLogic.SPError("Input \(i) (\(out.txid):\(out.vout)) is not a P2TR output.")
            }
            if psbt.inputs[i].contains(where: { $0.key == [SPPsbt.inTapKeySig] }) { continue }   // already signed

            // Sighash type: PSBT_IN_SIGHASH_TYPE if present, else SIGHASH_DEFAULT.
            var hashType: UInt8 = 0x00
            if let v = psbt.inputs[i].first(where: { $0.key == [SPPsbt.inSighashType] })?.value {
                guard v.count == 4 else { throw WalletLogic.SPError("Bad sighash type on input \(i).") }
                let t = UInt32(v[0]) | UInt32(v[1]) << 8 | UInt32(v[2]) << 16 | UInt32(v[3]) << 24
                guard t == 0 || t == 1 else {
                    throw WalletLogic.SPError("Input \(i) asks for sighash type \(t); only DEFAULT and ALL are supported.")
                }
                hashType = UInt8(t)
            }

            // d = b_spend + t_k (+ label_m) mod n.
            guard let tk = SPHexFN.decode(out.tweakHex), SPScalar.isValid(tk) else {
                throw WalletLogic.SPError("Invalid tweak for \(out.txid):\(out.vout).")
            }
            var d = SPScalar.add(bSpend, tk)
            if let lh = out.labelTweakHex {
                guard let label = SPHexFN.decode(lh), SPScalar.isValid(label) else {
                    throw WalletLogic.SPError("Invalid label tweak for \(out.txid):\(out.vout).")
                }
                d = SPScalar.add(d, label)
            }
            defer { d.secureZero() }
            guard SPScalar.isValid(d) else { throw WalletLogic.SPError("Tweaked key is zero for \(out.txid):\(out.vout).") }

            // Negate if d·G has odd Y, then check d·G is exactly this input's output key.
            var priv = try P256K.Schnorr.PrivateKey(dataRepresentation: d)
            if priv.xonly.parity { priv = priv.negation }
            let xonly = Data(priv.xonly.bytes)
            guard Data([0x51, 0x20]) + xonly == spk else {
                mismatches.append("\(out.txid):\(out.vout)")
                continue
            }

            // BIP341 sighash, BIP340 signature (random aux), verified before use.
            var msg = [UInt8](try SPSighash.taprootKeyPath(tx: tx, prevouts: prevouts, inputIndex: i, hashType: hashType))
            guard var aux = Crypto.secret(), aux.count == 32 else { throw WalletLogic.SPError("No randomness.") }
            let sig = try aux.withUnsafeMutableBytes { try priv.signature(message: &msg, auxiliaryRand: $0.baseAddress, strict: true) }
            aux.secureZero()
            guard priv.xonly.isValid(sig, for: &msg) else {
                throw WalletLogic.SPError("Signature for input \(i) failed verification.")
            }

            // 64-byte sig for DEFAULT, sig || hash_type for ALL.
            var value = sig.dataRepresentation
            if hashType != 0x00 { value.append(hashType) }
            psbt.inputs[i].append((key: [SPPsbt.inTapKeySig], value: [UInt8](value)))
            signed += 1
        }

        if signed == 0 {
            if !mismatches.isEmpty {
                throw KeyMismatch("The spend key doesn't match silent payment input(s) \(mismatches.joined(separator: ", ")). Wrong signer or passphrase?")
            }
            throw WalletLogic.SPError("No silent payment inputs to sign: none of the PSBT inputs are in the provided outputs (or they're already signed).")
        }
        if !mismatches.isEmpty {
            throw WalletLogic.SPError("Signed \(signed) input(s), but the key doesn't match \(mismatches.joined(separator: ", ")). Check the tweaks for those outputs.")
        }
        return (psbt.serialize().base64EncodedString(), signed)
    }

    // b_spend = m/352'/coin'/0'/0'/0 (BIP352 key derivation).
    private static func spendKey(master: DescriptorSecretKey) -> Data? {
        guard let path = try? BDKDerivationPathFN(path: SPSignerKeys.spendPath()),
              let child = try? master.derive(path: path) else { return nil }
        return Data(child.secretBytes())
    }

    // Thrown when the spend key doesn't reproduce an input's output key, so the
    // signer loop knows to try the next signer / passphrase.
    struct KeyMismatch: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }
}


// MARK: - Minimal PSBT v0 (BIP174)

// Parses a PSBT into raw key/value maps and re-serializes it unchanged apart from
// the entries we append. Only what signing needs is interpreted.
struct SPPsbt {
    typealias Entry = (key: [UInt8], value: [UInt8])

    static let globalUnsignedTx: UInt8 = 0x00
    static let globalVersion: UInt8 = 0xFB
    static let inNonWitnessUtxo: UInt8 = 0x00
    static let inWitnessUtxo: UInt8 = 0x01
    static let inSighashType: UInt8 = 0x03
    static let inTapKeySig: UInt8 = 0x13

    var global: [Entry]
    var inputs: [[Entry]]
    var outputs: [[Entry]]
    let tx: SPTx

    init(_ data: Data) throws {
        var r = SPReader([UInt8](data))
        guard try r.bytes(5) == [0x70, 0x73, 0x62, 0x74, 0xFF] else { throw WalletLogic.SPError("Not a PSBT.") }
        global = try SPPsbt.readMap(&r)
        if let v = global.first(where: { $0.key == [SPPsbt.globalVersion] })?.value, v != [0, 0, 0, 0] {
            throw WalletLogic.SPError("Only PSBT version 0 is supported.")
        }
        guard let txBytes = global.first(where: { $0.key == [SPPsbt.globalUnsignedTx] })?.value else {
            throw WalletLogic.SPError("PSBT has no unsigned transaction.")
        }
        tx = try SPTx(txBytes)
        inputs = try tx.inputs.map { _ in try SPPsbt.readMap(&r) }
        outputs = try tx.outputs.map { _ in try SPPsbt.readMap(&r) }
    }

    // Prevout (amount + scriptPubKey) of input `i`: witness_utxo, else non_witness_utxo.
    func prevout(input i: Int) throws -> SPTx.Output {
        if let v = inputs[i].first(where: { $0.key == [SPPsbt.inWitnessUtxo] })?.value {
            var r = SPReader(v)
            return try SPTx.readOutput(&r)
        }
        if let v = inputs[i].first(where: { $0.key == [SPPsbt.inNonWitnessUtxo] })?.value {
            let prev = try SPTx(v)
            let n = Int(tx.inputs[i].vout)
            guard n < prev.outputs.count else { throw WalletLogic.SPError("Input \(i): prevout index out of range.") }
            return prev.outputs[n]
        }
        throw WalletLogic.SPError("Input \(i) has no UTXO data in the PSBT; the sighash needs every input's amount and script.")
    }

    func serialize() -> Data {
        var out: [UInt8] = [0x70, 0x73, 0x62, 0x74, 0xFF]
        for map in [global] + inputs + outputs {
            for e in map {
                out += SPWriter.compactSize(e.key.count) + e.key
                out += SPWriter.compactSize(e.value.count) + e.value
            }
            out.append(0x00)
        }
        return Data(out)
    }

    private static func readMap(_ r: inout SPReader) throws -> [Entry] {
        var entries: [Entry] = []
        while true {
            let keyLen = try r.compactSize()
            if keyLen == 0 { return entries }
            let key = try r.bytes(keyLen)
            let value = try r.bytes(try r.compactSize())
            entries.append((key: key, value: value))
        }
    }
}


// MARK: - Transaction parsing

struct SPTx {
    struct Input {
        // 32-byte txid in internal byte order + 4-byte LE vout, as serialized.
        let outpoint: [UInt8]
        let sequence: [UInt8]
        var vout: UInt32 {
            UInt32(outpoint[32]) | UInt32(outpoint[33]) << 8 | UInt32(outpoint[34]) << 16 | UInt32(outpoint[35]) << 24
        }
        // Txid in RPC display order (hex).
        var txidDisplay: String { SPHexFN.encode(Data(outpoint[0..<32].reversed())) }
    }
    struct Output {
        let amount: [UInt8]   // 8 bytes LE
        let script: Data
        // amount || compactSize(len) || script, as serialized.
        var serialized: [UInt8] { amount + SPWriter.compactSize(script.count) + [UInt8](script) }
    }

    let version: [UInt8]
    let inputs: [Input]
    let outputs: [Output]
    let locktime: [UInt8]

    // Accepts both legacy and segwit serialization (non_witness_utxo may be either).
    init(_ bytes: [UInt8]) throws {
        var r = SPReader(bytes)
        version = try r.bytes(4)
        var segwit = false
        if r.peek(2) == [0x00, 0x01] { _ = try r.bytes(2); segwit = true }
        var ins: [Input] = []
        let inCount = try r.compactSize()
        for _ in 0..<inCount {
            let outpoint = try r.bytes(36)
            _ = try r.bytes(try r.compactSize())      // scriptSig
            ins.append(Input(outpoint: outpoint, sequence: try r.bytes(4)))
        }
        var outs: [Output] = []
        let outCount = try r.compactSize()
        for _ in 0..<outCount { outs.append(try SPTx.readOutput(&r)) }
        if segwit {
            for _ in ins {
                let items = try r.compactSize()
                for _ in 0..<items { _ = try r.bytes(try r.compactSize()) }
            }
        }
        locktime = try r.bytes(4)
        guard r.atEnd else { throw WalletLogic.SPError("Trailing bytes after transaction.") }
        inputs = ins
        outputs = outs
    }

    static func readOutput(_ r: inout SPReader) throws -> Output {
        let amount = try r.bytes(8)
        return Output(amount: amount, script: Data(try r.bytes(try r.compactSize())))
    }
}


// MARK: - BIP341 signature hash (key path, no annex)

enum SPSighash {
    /// hash_TapSighash(0x00 || SigMsg(hash_type, ext_flag = 0)) for SIGHASH_DEFAULT / SIGHASH_ALL.
    static func taprootKeyPath(tx: SPTx, prevouts: [SPTx.Output], inputIndex: Int, hashType: UInt8) throws -> Data {
        guard hashType == 0x00 || hashType == 0x01 else { throw WalletLogic.SPError("Unsupported sighash type.") }
        guard prevouts.count == tx.inputs.count, inputIndex < tx.inputs.count else {
            throw WalletLogic.SPError("Prevouts don't match the inputs.")
        }
        func sha(_ b: [UInt8]) -> [UInt8] { [UInt8](SHA256.hash(data: b)) }

        var msg: [UInt8] = [0x00]                                  // epoch
        msg.append(hashType)
        msg += tx.version
        msg += tx.locktime
        msg += sha(tx.inputs.flatMap { $0.outpoint })              // sha_prevouts
        msg += sha(prevouts.flatMap { $0.amount })                 // sha_amounts
        msg += sha(prevouts.flatMap { SPWriter.compactSize($0.script.count) + [UInt8]($0.script) })  // sha_scriptpubkeys
        msg += sha(tx.inputs.flatMap { $0.sequence })              // sha_sequences
        msg += sha(tx.outputs.flatMap { $0.serialized })           // sha_outputs
        msg.append(0x00)                                           // spend_type: key path, no annex
        msg += SPWriter.le32(UInt32(inputIndex))
        return SPHashFN.tagged("TapSighash", Data(msg))
    }
}


// MARK: - Byte reader / writer

struct SPReader {
    private let b: [UInt8]
    private var i = 0
    init(_ bytes: [UInt8]) { b = bytes }

    var atEnd: Bool { i == b.count }
    func peek(_ n: Int) -> [UInt8]? { i + n <= b.count ? Array(b[i..<i + n]) : nil }

    mutating func bytes(_ n: Int) throws -> [UInt8] {
        guard n >= 0, i + n <= b.count else { throw WalletLogic.SPError("Unexpected end of data.") }
        defer { i += n }
        return Array(b[i..<i + n])
    }

    mutating func compactSize() throws -> Int {
        let first = try bytes(1)[0]
        let width: Int
        switch first {
        case 0xFD: width = 2
        case 0xFE: width = 4
        case 0xFF: width = 8
        default: return Int(first)
        }
        let v = try bytes(width).enumerated().reduce(UInt64(0)) { $0 | UInt64($1.element) << (8 * UInt64($1.offset)) }
        guard v <= UInt64(b.count) else { throw WalletLogic.SPError("Length out of range.") }
        return Int(v)
    }
}

enum SPWriter {
    static func le32(_ v: UInt32) -> [UInt8] { (0..<4).map { UInt8(truncatingIfNeeded: v >> (8 * $0)) } }

    static func compactSize(_ n: Int) -> [UInt8] {
        switch n {
        case ..<0xFD: return [UInt8(n)]
        case ...0xFFFF: return [0xFD, UInt8(n & 0xFF), UInt8(n >> 8)]
        case ...0xFFFF_FFFF: return [0xFE] + le32(UInt32(n))
        default: return [0xFF] + (0..<8).map { UInt8(truncatingIfNeeded: UInt64(n) >> (8 * UInt64($0))) }
        }
    }
}

/*
 Usage: sign the SP inputs, then let Core (or the normal Signer for other inputs)
 finalize. `found` is FN-Server's saved SPScanState "found" array.

 let outputs = try JSONDecoder().decode([SilentPaymentSpend.OwnedOutput].self, from: foundJson)
 SilentPaymentSpend.sign(psbt: unsignedPsbt, outputs: outputs) { psbt, signed, error in
     // psbt has PSBT_IN_TAP_KEY_SIG for `signed` inputs → finalizepsbt → broadcast
 }
*/


// MARK: - Detecting silent payment inputs
//
// Decides whether a PSBT input spends a silent payment output you own WITHOUT relying
// on wallet labels: it re-runs BIP352 receiver scanning on the input's FUNDING
// transaction (fetched from your node with its prevouts) using each signer's scan key
// and spend public key. A match proves the output is yours AND yields the tweak t_k
// (and label tweak) that `sign(psbt:outputs:)` needs, so FN-Server's saved tweaks
// aren't required.

// MARK: - BIP352 keys of the stored signers

/// BIP352 derivation paths and the stored signers' master keys. Shared by signing,
/// input detection, sending and silent payment change, so they all try exactly the same
/// keys in the same order.
enum SPSignerKeys {
    /// b_spend: m/352'/coin'/0'/0'/0
    static func spendPath(mainnet: Bool = SPAddress.isMainnet) -> String {
        "m/352h/\(mainnet ? 0 : 1)h/0h/0h/0"
    }

    /// b_scan: m/352'/coin'/0'/1'/0
    static func scanPath(mainnet: Bool = SPAddress.isMainnet) -> String {
        "m/352h/\(mainnet ? 0 : 1)h/0h/1h/0"
    }

    /// Calls `body` with a master key for every stored signer and passphrase candidate:
    /// the typed passphrase, the signer's stored passphrase, then none (de-duplicated, in
    /// that order). Return true from `body` to stop. Decrypted words are wiped after each
    /// signer.
    static func forEachMaster(signers: [[String: Any]],
                              passphrase: String?,
                              _ body: (SignerStruct, DescriptorSecretKey) -> Bool) {
        let networkKind: NetworkKind = SPAddress.isMainnet ? .main : .test

        for dict in signers {
            let signer = SignerStruct(dictionary: dict)
            guard var encWords = signer.words,
                  var wordsData = Crypto.decrypt(encWords),
                  var words = wordsData.utf8String,
                  let mnemonic = try? Mnemonic.fromString(mnemonic: words) else { continue }
            defer {
                wordsData.secureZero()
                encWords.secureZero()
                words.secureWipe()
            }

            var candidates: [String] = [passphrase ?? ""]
            if let encPass = signer.passphrase, var passData = Crypto.decrypt(encPass), let p = passData.utf8String {
                candidates.append(p)
                passData.secureZero()
            }
            candidates.append("")
            var seen = Set<String>()

            for p in candidates where seen.insert(p).inserted {
                let master = DescriptorSecretKey(networkKind: networkKind,
                                                 mnemonic: mnemonic,
                                                 password: p.isEmpty ? nil : p)
                if body(signer, master) { return }
            }
        }
    }

    /// All master keys `forEachMaster` would produce.
    static func masters(signers: [[String: Any]], passphrase: String?) -> [DescriptorSecretKey] {
        var masters: [DescriptorSecretKey] = []
        forEachMaster(signers: signers, passphrase: passphrase) { _, master in
            masters.append(master)
            return false
        }
        return masters
    }
}

extension SilentPaymentSpend {

    /// Scan key pair derived from one signer (+ passphrase candidate).
    struct ScanKeys {
        var bScan: Data        // b_scan, 32 bytes (secret, wiped after use)
        let bSpendPub: Data    // B_spend, 33 bytes compressed
        var signerLabel: String = ""   // label of the signer these keys came from (display only)
    }

    /// Core wallet facts about an input's address (`getaddressinfo` in the active wallet).
    struct WalletInfo {
        let isMine: Bool
        let desc: String
        let labels: [String]
    }

    /// A taproot input that might be one of your silent payment outputs.
    struct Candidate {
        let txid: String
        let vout: Int
        /// x-only output key (hex) from the prevout script.
        let outputKey: String
        /// nil: looked up with `getaddressinfo`.
        var info: WalletInfo?
    }

    /// The Core wallet label FN-Server gives every output it imports:
    /// "sp scan=<B_scan hex> k=<k> [m=<label m>] [t=<t_k hex>]". Outputs imported before
    /// FN-Server added `t=` have no tweak.
    struct WalletLabel {
        let scanPub: String
        let m: UInt32?
        let tweakHex: String?

        init?(_ label: String) {
            let fields = label.split(separator: " ")
            guard fields.first == "sp" else { return nil }
            var values: [String: String] = [:]
            for field in fields.dropFirst() {
                let parts = field.split(separator: "=", maxSplits: 1)
                if parts.count == 2 { values[String(parts[0])] = String(parts[1]).lowercased() }
            }
            guard let scan = values["scan"], scan.count == 66 else { return nil }
            scanPub = scan
            m = values["m"].flatMap { UInt32($0) }
            tweakHex = values["t"].flatMap { $0.count == 64 ? $0 : nil }
        }
    }

    /// Finds which inputs of `psbt` are silent payment outputs paid to one of your
    /// signers, in the ACTIVE wallet. Only taproot inputs the wallet holds as a bare key
    /// (FN-Server's `rawtr()` imports) are considered; see `detect(candidates:)`.
    /// `knownInfo` ("txid:vout" lowercase → wallet info) skips `getaddressinfo` for
    /// inputs the caller already looked up. Completion (main queue) gets the owned
    /// outputs, ready for `sign(psbt:outputs:passphrase:completion:)`; empty if none.
    static func detectInputs(psbt: String,
                             passphrase: String?,
                             knownInfo: [String: WalletInfo] = [:],
                             completion: @escaping ([OwnedOutput]) -> Void) {
        let finish: ([OwnedOutput]) -> Void = { found in DispatchQueue.main.async { completion(found) } }

        guard let raw = Data(base64Encoded: psbt.trimmingCharacters(in: .whitespacesAndNewlines)),
              let parsed = try? SPPsbt(raw) else {
            finish([])
            return
        }

        // Taproot (OP_1 <32 bytes>) inputs only.
        var candidates: [Candidate] = []
        for (i, input) in parsed.tx.inputs.enumerated() {
            guard let prev = try? parsed.prevout(input: i) else { continue }
            let s = [UInt8](prev.script)
            guard s.count == 34, s[0] == 0x51, s[1] == 0x20 else { continue }
            let outpoint = "\(input.txidDisplay.lowercased()):\(input.vout)"
            candidates.append(Candidate(txid: input.txidDisplay,
                                        vout: Int(input.vout),
                                        outputKey: SPHexFN.encode(s[2..<34]),
                                        info: knownInfo[outpoint]))
        }

        detect(candidates: candidates, passphrase: passphrase) { found in
            finish(found.map { $0.output })
        }
    }

    /// For display: maps "txid:vout" (lowercase txid) of each of `candidates` that is a
    /// silent payment output you own to the label of the signer that can spend it.
    /// Completion on the main queue.
    static func detectInputSigners(candidates: [Candidate],
                                   passphrase: String?,
                                   completion: @escaping ([String: String]) -> Void) {
        detect(candidates: candidates, passphrase: passphrase) { found in
            var signers: [String: String] = [:]
            for item in found {
                signers["\(item.output.txid.lowercased()):\(item.output.vout)"] = item.signer
            }
            DispatchQueue.main.async { completion(signers) }
        }
    }

    /// Silent payment detection from what the active wallet already knows, without
    /// scanning anything for ordinary inputs:
    ///
    /// - Only inputs the wallet owns (`ismine`) as a bare taproot key qualify: FN-Server
    ///   imports each output it finds as `rawtr(<xonly>)` with the label
    ///   "sp scan=<B_scan> k=… [m=…] [t=<t_k>]". Normal wallet inputs (`tr(…)`, `wpkh(…)`)
    ///   are skipped with no extra work.
    /// - Label with `t=`: checked locally (B_spend [+ label_m·G] + t_k·G must be the
    ///   input's output key) against the signer whose scan key is in the label. No RPC.
    /// - Older imports (no `t=`) and `rawtr()`/`addr()` imports without the label: the
    ///   funding transaction of just those inputs is scanned (`match`).
    ///
    /// The tweak in a label is only a hint: signing still refuses unless the derived key
    /// reproduces the output key. Completion on any queue.
    static func detect(candidates: [Candidate],
                       passphrase: String?,
                       completion: @escaping ([(output: OwnedOutput, signer: String)]) -> Void) {
        guard !candidates.isEmpty else {
            completion([])
            return
        }

        fillWalletInfo(candidates) { candidates in
            // Bare taproot keys held by the active wallet; everything else can't be one of
            // FN-Server's imports.
            let possible = candidates.filter { candidate in
                guard let info = candidate.info, info.isMine else { return false }
                return info.labels.contains { WalletLabel($0) != nil }
                    || info.desc.hasPrefix("rawtr(")
                    || info.desc.hasPrefix("addr(")
            }
            guard !possible.isEmpty else {
                completion([])
                return
            }

            scanKeyCandidates(passphrase: passphrase) { keys in
                var keys = keys
                var found: [(output: OwnedOutput, signer: String)] = []
                var toScan: [(txid: String, vout: Int)] = []

                for candidate in possible {
                    let label = candidate.info?.labels.lazy.compactMap { WalletLabel($0) }.first
                    if let label = label {
                        // Only the signer named by the label's scan key can own it.
                        guard keys.contains(where: { scanPublicKey(of: $0) == label.scanPub }) else { continue }
                        if let tweakHex = label.tweakHex {
                            if let owned = ownedOutput(candidate, label: label, tweakHex: tweakHex, keys: keys) {
                                found.append(owned)
                            }
                            continue
                        }
                    }
                    toScan.append((candidate.txid, candidate.vout))
                }

                func done(_ scanned: [(output: OwnedOutput, signer: String)]) {
                    for i in keys.indices { keys[i].bScan.secureZero() }
                    completion(found + scanned)
                }

                guard !toScan.isEmpty else {
                    done([])
                    return
                }
                match(outpoints: toScan, keys: keys) { matches in
                    done(matches.map { (output: $0.output, signer: $0.signerLabel) })
                }
            }
        }
    }

    /// Looks up `getaddressinfo` (a cheap wallet call, no block data) for candidates
    /// whose wallet info isn't known yet. Completion on any queue.
    static func fillWalletInfo(_ candidates: [Candidate], completion: @escaping ([Candidate]) -> Void) {
        var result: [Candidate] = []
        var remaining = candidates

        func next() {
            guard !remaining.isEmpty else {
                completion(result)
                return
            }
            var candidate = remaining.removeFirst()
            guard candidate.info == nil,
                  let key = SPHexFN.decode(candidate.outputKey),
                  let address = try? SPAddress.p2tr(xonly: key) else {
                result.append(candidate)
                next()
                return
            }

            let param = Get_Address_Info(["address": address])
            MakeRPCCall.sharedInstance.executeRPCCommand(method: .getaddressinfo(param: param)) { response, _ in
                if let dict = response as? [String: Any] {
                    candidate.info = WalletInfo(isMine: dict["ismine"] as? Bool ?? false,
                                                desc: dict["desc"] as? String ?? "",
                                                labels: dict["labels"] as? [String] ?? [])
                }
                result.append(candidate)
                next()
            }
        }

        next()
    }

    /// B_scan (hex, compressed) of a scan key pair.
    static func scanPublicKey(of keys: ScanKeys) -> String? {
        guard let key = try? P256K.Signing.PrivateKey(dataRepresentation: keys.bScan) else { return nil }
        return SPHexFN.encode(Data(key.publicKey.dataRepresentation))
    }

    /// The owned output a wallet label describes, if it checks out: for the signer whose
    /// B_scan is in the label, B_spend (+ label_m·G) + t_k·G must equal the input's output
    /// key.
    static func ownedOutput(_ candidate: Candidate,
                            label: WalletLabel,
                            tweakHex: String,
                            keys: [ScanKeys]) -> (output: OwnedOutput, signer: String)? {
        guard let tweak = SPHexFN.decode(tweakHex), tweak.count == 32, SPScalar.isValid(tweak) else { return nil }

        for key in keys where scanPublicKey(of: key) == label.scanPub {
            guard var spend = try? P256K.Signing.PublicKey(dataRepresentation: key.bSpendPub, format: .compressed) else { continue }

            // label_m = hash_BIP0352/Label(b_scan || ser32(m)).
            var labelTweak: Data?
            if let m = label.m {
                var be = m.bigEndian
                let tweakM = SPHashFN.tagged("BIP0352/Label", key.bScan + Data(bytes: &be, count: 4))
                guard SPScalar.isValid(tweakM), let labeled = try? spend.add(Array(tweakM)) else { continue }
                spend = labeled
                labelTweak = tweakM
            }

            guard let output = try? spend.add(Array(tweak)),
                  SPHexFN.encode(Data(output.xonly.bytes)) == candidate.outputKey.lowercased() else { continue }

            let owned = OwnedOutput(txid: candidate.txid,
                                    vout: candidate.vout,
                                    tweakHex: SPHexFN.encode(tweak),
                                    labelTweakHex: labelTweak.map { SPHexFN.encode($0) })
            return (owned, key.signerLabel)
        }
        return nil
    }

    /// One owned output found by `match`.
    struct Match {
        let output: OwnedOutput
        let signerLabel: String
        /// Copy of the matching scan keys, only when `match` was asked for them (the
        /// caller then owns it and must wipe `bScan`).
        let keys: ScanKeys?
    }

    /// BIP352 receiver check of each outpoint against `keys`: fetches each funding
    /// transaction from the node (one at a time) and scans it with every key until one
    /// matches. With `firstOnly` it stops at the first match; with `copyKeys` each match
    /// carries a copy of its keys. `keys` are wiped when done. Completion on any queue.
    /// Used by input detection and by silent payment change's owner lookup.
    static func match(outpoints: [(txid: String, vout: Int)],
                      keys: [ScanKeys],
                      firstOnly: Bool = false,
                      copyKeys: Bool = false,
                      completion: @escaping ([Match]) -> Void) {
        var keys = keys
        var found: [Match] = []
        var remaining = outpoints

        func finish() {
            for i in keys.indices { keys[i].bScan.secureZero() }
            completion(found)
        }

        func next() {
            guard !keys.isEmpty, let candidate = remaining.first, !(firstOnly && !found.isEmpty) else {
                finish()
                return
            }
            remaining.removeFirst()

            fetchFundingTransaction(txid: candidate.txid) { tx in
                DispatchQueue.global(qos: .userInitiated).async {
                    if let tx = tx {
                        for key in keys {
                            if let owned = scan(fundingTx: tx, txid: candidate.txid, vout: candidate.vout, keys: key) {
                                let copy = copyKeys ? ScanKeys(bScan: Data(Array(key.bScan)),
                                                               bSpendPub: key.bSpendPub,
                                                               signerLabel: key.signerLabel) : nil
                                found.append(Match(output: owned, signerLabel: key.signerLabel, keys: copy))
                                break
                            }
                        }
                    }
                    next()
                }
            }
        }

        next()
    }

    /// The funding transaction with prevouts (`getrawtransaction <txid> 2 [blockhash]`,
    /// Core ≥ 25). The block hash comes from the wallet so -txindex isn't needed.
    static func fetchFundingTransaction(txid: String, completion: @escaping ([String: Any]?) -> Void) {
        let walletTx = Get_Tx(["txid": txid, "verbose": false])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .gettransaction(walletTx)) { response, _ in
            var params: [String: Any] = ["txid": txid, "verbosity": 2]
            if let blockhash = (response as? [String: Any])?["blockhash"] as? String {
                params["blockhash"] = blockhash
            }
            MakeRPCCall.sharedInstance.executeRPCCommand(method: .getrawtransaction(param: Get_Raw_Tx(params))) { response, _ in
                completion(response as? [String: Any])
            }
        }
    }

    /// b_scan (m/352'/coin'/0'/1'/0) and B_spend (m/352'/coin'/0'/0'/0) for every signer,
    /// trying the same passphrase candidates as `sign(...)`: typed, stored, none.
    static func scanKeyCandidates(passphrase: String?, completion: @escaping ([ScanKeys]) -> Void) {
        CoreDataService.retrieveEntity(entityName: .signers) { signers in
            var result: [ScanKeys] = []
            guard let scanPath = try? BDKDerivationPathFN(path: SPSignerKeys.scanPath()),
                  let spendPath = try? BDKDerivationPathFN(path: SPSignerKeys.spendPath()) else {
                completion(result)
                return
            }

            SPSignerKeys.forEachMaster(signers: signers ?? [], passphrase: passphrase) { signer, master in
                guard let scanKey = try? master.derive(path: scanPath),
                      let spendKey = try? master.derive(path: spendPath) else { return false }

                var spendPriv = Data(spendKey.secretBytes())
                defer { spendPriv.secureZero() }
                guard let spendPub = try? P256K.Signing.PrivateKey(dataRepresentation: spendPriv).publicKey else { return false }

                result.append(ScanKeys(bScan: Data(scanKey.secretBytes()),
                                       bSpendPub: Data(spendPub.dataRepresentation),
                                       signerLabel: signer.label))
                return false
            }
            completion(result)
        }
    }

    /// BIP352 receiver check of one funding transaction (decoded JSON with vin.prevout)
    /// for output `vout`. Returns the owned output (t_k, label tweak) if it's ours.
    static func scan(fundingTx tx: [String: Any], txid: String, vout target: Int, keys: ScanKeys) -> OwnedOutput? {
        guard let vins = tx["vin"] as? [[String: Any]],
              let vouts = tx["vout"] as? [[String: Any]],
              !vins.isEmpty else { return nil }

        // Coinbase can't be a silent payment.
        if vins.first?["coinbase"] != nil { return nil }
        // Every input needs its prevout (verbosity 2 / undo data), otherwise A is unknown.
        if vins.contains(where: { $0["prevout"] == nil }) { return nil }
        // BIP352: a tx spending any segwit v2+ output isn't a silent payment.
        for vin in vins {
            if let spk = ((vin["prevout"] as? [String: Any])?["scriptPubKey"] as? [String: Any])?["hex"] as? String,
               SPDetect.isSegwitV2Plus(spk) {
                return nil
            }
        }

        // Taproot outputs (n → x-only key); the target must be one of them.
        var taproot: [Int: String] = [:]
        for (idx, out) in vouts.enumerated() {
            guard let hex = ((out["scriptPubKey"] as? [String: Any])?["hex"] as? String)?.lowercased(),
                  SPDetect.isP2TR(hex) else { continue }
            let n = (out["n"] as? NSNumber)?.intValue ?? idx
            taproot[n] = String(hex.dropFirst(4))
        }
        guard let targetXonly = taproot[target] else { return nil }

        // Eligible input keys and ALL outpoints.
        var pubkeys: [Data] = []
        var outpoints: [Data] = []
        for vin in vins {
            if let prevTxid = vin["txid"] as? String,
               let n = (vin["vout"] as? NSNumber)?.uint32Value,
               let txidBytes = SPHexFN.decode(prevTxid), txidBytes.count == 32 {
                var le = n.littleEndian
                outpoints.append(Data(txidBytes.reversed()) + Data(bytes: &le, count: 4))
            }
            if let pk = SPDetect.eligiblePubkey(vin: vin) { pubkeys.append(pk) }
        }
        guard !pubkeys.isEmpty,
              let smallest = outpoints.min(by: { $0.lexicographicallyPrecedes($1) }) else { return nil }

        do {
            // A = Σ input keys (throws if it's the point at infinity → not a silent payment).
            let parsed = try pubkeys.map { try P256K.Signing.PublicKey(dataRepresentation: $0, format: .compressed) }
            let sum: P256K.Signing.PublicKey
            if parsed.count == 1 {
                sum = parsed[0]
            } else {
                sum = try parsed[0].combine(Array(parsed.dropFirst()), format: .compressed)
            }
            let aSum = Data(sum.dataRepresentation)

            // input_hash = hash_BIP0352/Inputs(outpoint_L || A)
            let inputHash = SPHashFN.tagged("BIP0352/Inputs", smallest + aSum)
            guard SPScalar.isValid(inputHash), SPScalar.isValid(keys.bScan) else { return nil }

            // ecdh = (input_hash · b_scan) · A  (two scalar multiplications of A)
            let ecdh = try sum.multiply(Array(keys.bScan), format: .compressed)
                              .multiply(Array(inputHash), format: .compressed)
            let sharedPoint = Data(ecdh.dataRepresentation)

            let bSpend = try P256K.Signing.PublicKey(dataRepresentation: keys.bSpendPub, format: .compressed)
            // Change label m = 0 is always scanned (BIP352).
            let label0 = SPHashFN.tagged("BIP0352/Label", keys.bScan + Data([0, 0, 0, 0]))
            let bSpendLabel0 = try bSpend.add(Array(label0))

            var remaining = Set(taproot.values)
            var k: UInt32 = 0
            while k < 2323, !remaining.isEmpty {
                var be = k.bigEndian
                let tk = SPHashFN.tagged("BIP0352/SharedSecret", sharedPoint + Data(bytes: &be, count: 4))
                guard SPScalar.isValid(tk) else { return nil }

                var hit = false

                let unlabeled = SPHexFN.encode(Data(try bSpend.add(Array(tk)).xonly.bytes))
                if remaining.remove(unlabeled) != nil {
                    hit = true
                    if unlabeled == targetXonly {
                        return OwnedOutput(txid: txid, vout: target, tweakHex: SPHexFN.encode(tk), labelTweakHex: nil)
                    }
                }

                let labeled = SPHexFN.encode(Data(try bSpendLabel0.add(Array(tk)).xonly.bytes))
                if remaining.remove(labeled) != nil {
                    hit = true
                    if labeled == targetXonly {
                        return OwnedOutput(txid: txid, vout: target, tweakHex: SPHexFN.encode(tk), labelTweakHex: SPHexFN.encode(label0))
                    }
                }

                if !hit { break }
                k += 1
            }
        } catch {
            return nil
        }
        return nil
    }
}

/// BIP352 input rules used by detection (same rules as FN-Server's scanner, checked
/// against the BIP352 test vectors).
enum SPDetect {
    static let numsH = "50929b74c1a04954b78b4b6035e97a5e078a5a0f28ec96d547bfee9ace803ac0"

    // Output script templates (hex, compared as given: pass lowercase hex).
    /// OP_1 <32>: P2TR.
    static func isP2TR(_ spk: String) -> Bool { spk.count == 68 && spk.hasPrefix("5120") }
    /// OP_0 <20>: P2WPKH.
    static func isP2WPKH(_ spk: String) -> Bool { spk.count == 44 && spk.hasPrefix("0014") }
    /// OP_HASH160 <20> OP_EQUAL: P2SH.
    static func isP2SH(_ spk: String) -> Bool { spk.count == 46 && spk.hasPrefix("a914") && spk.hasSuffix("87") }
    /// OP_DUP OP_HASH160 <20> OP_EQUALVERIFY OP_CHECKSIG: P2PKH.
    static func isP2PKH(_ spk: String) -> Bool { spk.count == 50 && spk.hasPrefix("76a914") && spk.hasSuffix("88ac") }

    /// Witness program of version 2…16 (exactly OP_n <2…40-byte push>).
    static func isSegwitV2Plus(_ hex: String) -> Bool {
        guard let s = SPHexFN.decode(hex).map({ [UInt8]($0) }), s.count >= 4, s.count <= 42 else { return false }
        let pushLen = Int(s[1])
        guard (2...40).contains(pushLen), s.count == pushLen + 2 else { return false }
        return (0x52...0x60).contains(s[0])
    }

    /// Compressed public key an input contributes to A, or nil if it's not eligible.
    static func eligiblePubkey(vin: [String: Any]) -> Data? {
        guard let spk = (((vin["prevout"] as? [String: Any])?["scriptPubKey"] as? [String: Any])?["hex"] as? String)?.lowercased()
        else { return nil }
        let witness = (vin["txinwitness"] as? [String] ?? []).map { $0.lowercased() }
        let scriptSig = ((vin["scriptSig"] as? [String: Any])?["hex"] as? String ?? "").lowercased()

        func compressed(_ hex: String) -> Data? {
            guard hex.count == 66, hex.hasPrefix("02") || hex.hasPrefix("03") else { return nil }
            return SPHexFN.decode(hex)
        }

        // P2TR: even-Y output key, unless a script-path spend with the NUMS internal key.
        if SPDetect.isP2TR(spk) {
            var stack = witness
            if stack.count >= 2, let last = stack.last, last.hasPrefix("50") { stack.removeLast() }  // annex
            if stack.count >= 2, let control = stack.last, control.count >= 66,
               String(control.dropFirst(2).prefix(64)) == numsH {
                return nil
            }
            return SPHexFN.decode("02" + String(spk.dropFirst(4)))
        }
        // P2WPKH: witness [sig, pubkey].
        if SPDetect.isP2WPKH(spk) {
            return witness.count == 2 ? witness.last.flatMap(compressed) : nil
        }
        // P2SH-P2WPKH: scriptSig is exactly the 0x16 0014<20> push.
        if SPDetect.isP2SH(spk) {
            guard scriptSig.count == 46, scriptSig.hasPrefix("160014"), witness.count == 2 else { return nil }
            return witness.last.flatMap(compressed)
        }
        // P2PKH: last 33-byte window of the scriptSig whose HASH160 matches.
        if SPDetect.isP2PKH(spk) {
            guard let want = SPHexFN.decode(String(spk.dropFirst(6).prefix(40))),
                  let sig = SPHexFN.decode(scriptSig) else { return nil }
            let bytes = [UInt8](sig)
            var end = bytes.count
            while end >= 33 {
                let window = Data(bytes[(end - 33)..<end])
                if let first = window.first, first == 0x02 || first == 0x03,
                   SPHashFN.hash160(window) == want {
                    return window
                }
                end -= 1
            }
            return nil
        }
        return nil
    }
}

/// RIPEMD-160 (CryptoKit has none), for HASH160 (`SPHashFN.hash160`): silent payment
/// input keys and BIP32 key fingerprints. Same code as FN-Server's scanner, checked
/// against the RIPEMD-160 test vectors.
enum SPRIPEMD160 {
    private static let ML: [Int] = [
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
        7, 4, 13, 1, 10, 6, 15, 3, 12, 0, 9, 5, 2, 14, 11, 8,
        3, 10, 14, 4, 9, 15, 8, 1, 2, 7, 0, 6, 13, 11, 5, 12,
        1, 9, 11, 10, 0, 8, 12, 4, 13, 3, 7, 15, 14, 5, 6, 2,
        4, 0, 5, 9, 7, 12, 2, 10, 14, 1, 3, 8, 11, 6, 15, 13
    ]
    private static let MR: [Int] = [
        5, 14, 7, 0, 9, 2, 11, 4, 13, 6, 15, 8, 1, 10, 3, 12,
        6, 11, 3, 7, 0, 13, 5, 10, 14, 15, 8, 12, 4, 9, 1, 2,
        15, 5, 1, 3, 7, 14, 6, 9, 11, 8, 12, 2, 10, 0, 4, 13,
        8, 6, 4, 1, 3, 11, 15, 0, 5, 12, 2, 13, 9, 7, 10, 14,
        12, 15, 10, 4, 1, 5, 8, 7, 6, 2, 13, 14, 0, 3, 9, 11
    ]
    private static let RL: [UInt32] = [
        11, 14, 15, 12, 5, 8, 7, 9, 11, 13, 14, 15, 6, 7, 9, 8,
        7, 6, 8, 13, 11, 9, 7, 15, 7, 12, 15, 9, 11, 7, 13, 12,
        11, 13, 6, 7, 14, 9, 13, 15, 14, 8, 13, 6, 5, 12, 7, 5,
        11, 12, 14, 15, 14, 15, 9, 8, 9, 14, 5, 6, 8, 6, 5, 12,
        9, 15, 5, 11, 6, 8, 13, 12, 5, 12, 13, 14, 11, 8, 5, 6
    ]
    private static let RR: [UInt32] = [
        8, 9, 9, 11, 13, 15, 15, 5, 7, 7, 8, 11, 14, 14, 12, 6,
        9, 13, 15, 7, 12, 8, 9, 11, 7, 7, 12, 7, 6, 15, 13, 11,
        9, 7, 15, 11, 8, 6, 6, 14, 12, 13, 5, 14, 13, 13, 7, 5,
        15, 5, 8, 11, 14, 14, 6, 14, 6, 9, 12, 9, 12, 5, 15, 8,
        8, 5, 12, 9, 12, 5, 14, 6, 8, 13, 6, 5, 15, 13, 11, 11
    ]
    private static let KL: [UInt32] = [0, 0x5a827999, 0x6ed9eba1, 0x8f1bbcdc, 0xa953fd4e]
    private static let KR: [UInt32] = [0x50a28be6, 0x5c4dd124, 0x6d703ef3, 0x7a6d76e9, 0]

    private static func f(_ x: UInt32, _ y: UInt32, _ z: UInt32, _ i: Int) -> UInt32 {
        switch i {
        case 0: return x ^ y ^ z
        case 1: return (x & y) | (~x & z)
        case 2: return (x | ~y) ^ z
        case 3: return (x & z) | (y & ~z)
        default: return x ^ (y | ~z)
        }
    }

    private static func rol(_ x: UInt32, _ n: UInt32) -> UInt32 {
        return (x << n) | (x >> (32 - n))
    }

    private static func compress(_ h: inout [UInt32], _ block: ArraySlice<UInt8>) {
        var x = [UInt32](repeating: 0, count: 16)
        let base = block.startIndex
        for i in 0..<16 {
            let o = base + 4 * i
            let b0 = UInt32(block[o])
            let b1 = UInt32(block[o + 1]) << 8
            let b2 = UInt32(block[o + 2]) << 16
            let b3 = UInt32(block[o + 3]) << 24
            x[i] = b0 | b1 | b2 | b3
        }
        var al = h[0], bl = h[1], cl = h[2], dl = h[3], el = h[4]
        var ar = h[0], br = h[1], cr = h[2], dr = h[3], er = h[4]
        for j in 0..<80 {
            let rnd = j >> 4
            var t = al &+ f(bl, cl, dl, rnd) &+ x[ML[j]] &+ KL[rnd]
            t = rol(t, RL[j]) &+ el
            al = el; el = dl; dl = rol(cl, 10); cl = bl; bl = t
            t = ar &+ f(br, cr, dr, 4 - rnd) &+ x[MR[j]] &+ KR[rnd]
            t = rol(t, RR[j]) &+ er
            ar = er; er = dr; dr = rol(cr, 10); cr = br; br = t
        }
        let t = h[1] &+ cl &+ dr
        h[1] = h[2] &+ dl &+ er
        h[2] = h[3] &+ el &+ ar
        h[3] = h[4] &+ al &+ br
        h[4] = h[0] &+ bl &+ cr
        h[0] = t
    }

    static func hash(_ data: Data) -> Data {
        let msg = [UInt8](data)
        var h: [UInt32] = [0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, 0xc3d2e1f0]
        let full = msg.count / 64
        for b in 0..<full {
            compress(&h, msg[(64 * b) ..< (64 * (b + 1))])
        }
        var fin = Array(msg[(64 * full)...])
        fin.append(0x80)
        while fin.count % 64 != 56 { fin.append(0) }
        let bitLen = UInt64(msg.count) * 8
        for i in 0..<8 { fin.append(UInt8(truncatingIfNeeded: bitLen >> (8 * UInt64(i)))) }
        for b in 0..<(fin.count / 64) {
            compress(&h, fin[(64 * b) ..< (64 * (b + 1))])
        }
        var out = Data(capacity: 20)
        for v in h {
            for i in 0..<4 { out.append(UInt8(truncatingIfNeeded: v >> (8 * UInt32(i)))) }
        }
        return out
    }
}

// MARK: - Silent payment change

/// Silent payment change: offered whenever a transaction spends silent payment outputs
/// (the alternative being the wallet's normal change address).
///
/// The change goes to the CHANGE address of the signer that owns the inputs:
/// BIP352 label m = 0, i.e. B_m = B_spend + label_0·G. FN-Server always scans label 0
/// and Fully Noded's input detection always checks it, so the change shows up in the
/// same wallet and is spendable like any other silent payment output.
///
/// Because we're the recipient, the output key needs no input private keys: the shared
/// secret is computed exactly as when scanning (input_hash · b_scan · A).
///
///   1. Fund with a placeholder P2TR change address (same size as the real one), so
///      Core picks the inputs and fee.
///   2. Find the signer that owns the inputs (detection as in the verifier).
///   3. Compute P = B_spend + label_0·G + t_0·G from the chosen inputs.
///   4. Self-check with our own receiver scan, then rebuild with exactly the same
///      inputs and amounts (createpsbt), change → P2TR(P), and verify the result.
///
/// The pieces are also used by `SilentPaymentSend` (silent payment change when paying
/// another silent payment address).
enum SilentPaymentChange {

    /// Where the change of a transaction should go.
    enum Destination {
        /// The wallet's own change address (Fully Noded wallets always have one).
        case wallet
        /// Your silent payment change address (label 0 of the signer owning the inputs).
        case silentPayment
    }

    /// Placeholder change output: P2TR of the NUMS point (valid key nobody can spend).
    /// Same size as a real silent payment output. Never signed or broadcast.
    static let placeholderScript = "5120" + SPDetect.numsH
    static func placeholderAddress() -> String? {
        guard let nums = SPHexFN.decode(SPDetect.numsH) else { return nil }
        return try? SPAddress.p2tr(xonly: nums)
    }

    /// Builds an UNSIGNED psbt paying `outputs` with change to your silent payment
    /// change address. Completion on the main queue: (psbt, error).
    static func create(inputs: [[String: Any]],
                       outputs: [[String: Any]],
                       passphrase: String? = nil,
                       completion: @escaping (_ psbt: String?, _ errorMessage: String?) -> Void) {
        let done: (String?, String?) -> Void = { psbt, error in
            DispatchQueue.main.async { completion(psbt, error) }
        }

        guard let placeholder = placeholderAddress() else {
            done(nil, "Unable to build the placeholder change output.")
            return
        }

        // 1. Let Core choose inputs and fee.
        CreatePSBT.create(inputs: inputs, outputs: outputs, changeAddress: placeholder) { funded, _, error in
            guard let funded = funded else {
                done(nil, error ?? "walletcreatefundedpsbt failed.")
                return
            }

            decode(funded) { tx, error in
                guard let tx = tx else {
                    done(nil, error ?? "decodepsbt failed.")
                    return
                }

                // Exact amounts: no change needed, nothing to replace.
                guard let changeIndex = tx.outputs.firstIndex(where: { $0.script == placeholderScript }) else {
                    done(funded, nil)
                    return
                }

                // 2–3. The change output, self-checked.
                change(for: tx, changeIndex: changeIndex, passphrase: passphrase, recipientScanPub: nil) { address, script, error in
                    guard let address = address, let script = script else {
                        done(nil, error)
                        return
                    }
                    // 4. Rebuild with the real change.
                    rebuild(tx: tx, replacing: [changeIndex: (address, script)], completion: done)
                }
            }
        }
    }

    // MARK: Building blocks

    /// How an input counts for BIP352 (receiver side, as it will be broadcast).
    enum InputKind {
        case p2tr           // key path: contributes its even-Y output key
        case p2trNums       // script path with the NUMS internal key: contributes nothing
        case p2wpkh, p2shP2wpkh, p2pkh
        case ineligible     // e.g. P2WSH multisig: contributes nothing (outpoint still counts)
        case unknown        // eligible type but its public key isn't in the PSBT
        case segwitV2Plus   // makes the whole transaction ineligible
    }

    struct Input {
        let txid: String
        let vout: Int
        let sequence: Int
        let script: String          // prevout scriptPubKey hex
        var kind: InputKind = .ineligible
        var pubkey: Data? = nil     // compressed key this input adds to A (nil if none)

        // 36-byte outpoint: txid (internal byte order) || vout LE.
        var outpoint: Data {
            var d = Data((SPHexFN.decode(txid) ?? Data()).reversed())
            var le = UInt32(vout).littleEndian
            d.append(Data(bytes: &le, count: 4))
            return d
        }
    }

    struct Output {
        let value: Double
        let script: String
        let address: String?
    }

    struct Tx {
        let inputs: [Input]
        let outputs: [Output]
        var locktime: Int = 0
    }

    /// decodepsbt → inputs (with prevout scripts and sequences) and outputs.
    static func decode(_ psbt: String, completion: @escaping (Tx?, String?) -> Void) {
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .decodepsbt(param: Decode_Psbt(["psbt": psbt]))) { response, error in
            guard let dict = response as? [String: Any],
                  let tx = dict["tx"] as? [String: Any],
                  let vin = tx["vin"] as? [[String: Any]],
                  let vout = tx["vout"] as? [[String: Any]],
                  let pins = dict["inputs"] as? [[String: Any]], pins.count == vin.count else {
                completion(nil, error ?? "Unexpected decodepsbt response.")
                return
            }

            var inputs: [Input] = []
            for (i, txin) in vin.enumerated() {
                guard let txid = txin["txid"] as? String,
                      let n = (txin["vout"] as? NSNumber)?.intValue,
                      let seq = (txin["sequence"] as? NSNumber)?.intValue else {
                    completion(nil, "Input \(i) is incomplete.")
                    return
                }
                var script = ((pins[i]["witness_utxo"] as? [String: Any])?["scriptPubKey"] as? [String: Any])?["hex"] as? String
                if script == nil,
                   let nwu = pins[i]["non_witness_utxo"] as? [String: Any],
                   let outs = nwu["vout"] as? [[String: Any]], outs.indices.contains(n) {
                    script = (outs[n]["scriptPubKey"] as? [String: Any])?["hex"] as? String
                }
                guard let spk = script?.lowercased() else {
                    completion(nil, "Input \(i) has no prevout.")
                    return
                }
                let (kind, pubkey) = classify(script: spk, psbtInput: pins[i])
                inputs.append(Input(txid: txid, vout: n, sequence: seq, script: spk, kind: kind, pubkey: pubkey))
            }

            var outputs: [Output] = []
            for out in vout {
                let spk = out["scriptPubKey"] as? [String: Any]
                guard let value = (out["value"] as? NSNumber)?.doubleValue,
                      let hex = (spk?["hex"] as? String)?.lowercased() else {
                    completion(nil, "Unexpected output in decodepsbt.")
                    return
                }
                outputs.append(Output(value: value, script: hex, address: spk?["address"] as? String))
            }
            let locktime = (tx["locktime"] as? NSNumber)?.intValue ?? 0
            completion(Tx(inputs: inputs, outputs: outputs, locktime: locktime), nil)
        }
    }

    /// BIP352 kind and contributed public key of one PSBT input. The key comes from the
    /// prevout script (taproot) or from the PSBT's BIP32 derivations, and is only used
    /// if it hashes to the script.
    static func classify(script spk: String, psbtInput pin: [String: Any]) -> (InputKind, Data?) {
        if SPDetect.isSegwitV2Plus(spk) { return (.segwitV2Plus, nil) }

        let derivPubs: [Data] = (pin["bip32_derivs"] as? [[String: Any]] ?? [])
            .compactMap { ($0["pubkey"] as? String).flatMap(SPHexFN.decode) }
            .filter { $0.count == 33 && ($0.first == 0x02 || $0.first == 0x03) }

        // P2TR: even-Y output key, unless it's spent via script path with the NUMS
        // internal key (BIP352 excludes those).
        if SPDetect.isP2TR(spk) {
            let internalKey = (pin["taproot_internal_key"] as? String)?.lowercased()
            if internalKey == SPDetect.numsH { return (.p2trNums, nil) }
            return (.p2tr, SPHexFN.decode("02" + String(spk.dropFirst(4))))
        }
        // P2WPKH
        if SPDetect.isP2WPKH(spk) {
            let program = SPHexFN.decode(String(spk.dropFirst(4)))
            if let pub = derivPubs.first(where: { SPHashFN.hash160($0) == program }) { return (.p2wpkh, pub) }
            return (.unknown, nil)
        }
        // P2SH: only P2SH-P2WPKH is eligible.
        if SPDetect.isP2SH(spk) {
            guard let redeemHex = ((pin["redeem_script"] as? [String: Any])?["hex"] as? String)?.lowercased(),
                  let redeem = SPHexFN.decode(redeemHex) else { return (.unknown, nil) }
            guard SPDetect.isP2WPKH(redeemHex) else { return (.ineligible, nil) }
            let program = SPHexFN.decode(String(redeemHex.dropFirst(4)))
            guard SPHexFN.decode(String(spk.dropFirst(4).prefix(40))) == SPHashFN.hash160(redeem),
                  let pub = derivPubs.first(where: { SPHashFN.hash160($0) == program }) else { return (.unknown, nil) }
            return (.p2shP2wpkh, pub)
        }
        // P2PKH (compressed keys only)
        if SPDetect.isP2PKH(spk) {
            let hash = SPHexFN.decode(String(spk.dropFirst(6).prefix(40)))
            if let pub = derivPubs.first(where: { SPHashFN.hash160($0) == hash }) { return (.p2pkh, pub) }
            return (.unknown, nil)
        }
        // P2WSH, bare multisig, anchors, …
        return (.ineligible, nil)
    }

    /// Silent payment change for output `changeIndex` of `tx`: owner lookup, key and
    /// self-check.
    /// - recipientScanPub: B_scan of a silent payment recipient in the same tx (paid at
    ///   k = 0). If that's YOUR address, change shares the same scan key and takes the
    ///   next output index, k = 1 (BIP352: outputs to one B_scan get k = 0, 1, …).
    /// - finalScripts: real scriptPubKeys of outputs that are still placeholders in
    ///   `tx` (e.g. the recipient), so the self-check sees the transaction as broadcast.
    /// Completion on any queue.
    static func change(for tx: Tx,
                       changeIndex: Int,
                       passphrase: String?,
                       recipientScanPub: Data?,
                       finalScripts: [Int: String] = [:],
                       completion: @escaping (_ address: String?, _ script: String?, _ error: String?) -> Void) {
        // A is the sum of the eligible inputs' public keys, so every eligible input's
        // key must be known, and no input may be segwit v2+ (that makes the whole
        // transaction ineligible for silent payments).
        if tx.inputs.contains(where: { $0.kind == .segwitV2Plus }) {
            completion(nil, nil, "An input spends a segwit v2+ output, so this transaction can't use silent payment change.")
            return
        }
        if let i = tx.inputs.firstIndex(where: { $0.kind == .unknown }) {
            completion(nil, nil, "The public key of input \(i) isn't in the transaction, so silent payment change can't be computed. Use the wallet's change address instead.")
            return
        }
        guard tx.inputs.contains(where: { $0.pubkey != nil }) else {
            completion(nil, nil, "No input is eligible for silent payments.")
            return
        }

        owner(of: tx.inputs, passphrase: passphrase) { keys in
            guard var keys = keys else {
                completion(nil, nil, "None of the inputs belong to one of your signers' silent payment addresses. Enter a change address instead.")
                return
            }
            defer { keys.bScan.secureZero() }

            // Paying your own silent payment address too? Then that output is k = 0
            // for this scan key and the change is k = 1.
            var k: UInt32 = 0
            if let recipientScanPub = recipientScanPub,
               let bScanPub = try? P256K.Signing.PrivateKey(dataRepresentation: keys.bScan).publicKey,
               Data(bScanPub.dataRepresentation) == recipientScanPub {
                k = 1
            }

            do {
                let xonly = try changeKey(inputs: tx.inputs, keys: keys, k: k)
                let address = try SPAddress.p2tr(xonly: xonly)
                let script = "5120" + SPHexFN.encode(xonly)
                // Our own receiver scan (the code FN-Server mirrors and the verifier
                // uses) must find it, exactly as the transaction will be broadcast.
                var scripts = finalScripts
                scripts[changeIndex] = script
                guard selfCheck(tx: tx, changeIndex: changeIndex, finalScripts: scripts, keys: keys) else {
                    completion(nil, nil, "Silent payment change self-check failed. Aborted.")
                    return
                }
                completion(address, script, nil)
            } catch {
                completion(nil, nil, error.localizedDescription)
            }
        }
    }

    /// Rebuilds `tx` with exactly the same inputs (and sequences) and output amounts, so
    /// the fee is unchanged, replacing the outputs in `replacing` (index → new address
    /// and its script). Adds prevouts / derivations with walletprocesspsbt (no signing)
    /// and verifies the result. Completion on any queue.
    static func rebuild(tx: Tx,
                        replacing: [Int: (address: String, script: String)],
                        completion: @escaping (_ psbt: String?, _ error: String?) -> Void) {
        var outs: [[String: Any]] = []
        for (i, out) in tx.outputs.enumerated() {
            guard let address = replacing[i]?.address ?? out.address else {
                completion(nil, "Output \(i) has no address; can't rebuild the transaction.")
                return
            }
            outs.append([address: String(format: "%.8f", out.value)])
        }
        let ins: [[String: Any]] = tx.inputs.map { ["txid": $0.txid, "vout": $0.vout, "sequence": $0.sequence] }

        let create = Create_Psbt(["inputs": ins, "outputs": outs, "locktime": tx.locktime])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .createpsbt(create)) { response, error in
            guard let bare = response as? String else {
                completion(nil, error ?? "createpsbt failed.")
                return
            }
            let process = Wallet_Process_PSBT(["psbt": bare, "sign": false, "sighashtype": "DEFAULT", "finalize": false])
            MakeRPCCall.sharedInstance.executeRPCCommand(method: .walletprocesspsbt(param: process)) { response, error in
                guard let processed = (response as? [String: Any])?["psbt"] as? String else {
                    completion(nil, error ?? "walletprocesspsbt failed.")
                    return
                }

                decode(processed) { final, error in
                    guard let final = final else {
                        completion(nil, error ?? "decodepsbt (final) failed.")
                        return
                    }
                    let sameInputs = final.inputs.map { "\($0.txid):\($0.vout)" } == tx.inputs.map { "\($0.txid):\($0.vout)" }
                    let sameAmounts = final.outputs.map { $0.value } == tx.outputs.map { $0.value }
                    let replaced = replacing.allSatisfy { index, new in
                        final.outputs.indices.contains(index) && final.outputs[index].script == new.script
                    }
                    guard sameInputs, sameAmounts, replaced else {
                        completion(nil, "The rebuilt transaction doesn't match. Aborted.")
                        return
                    }
                    completion(processed, nil)
                }
            }
        }
    }

    /// Scan keys of the signer that owns (at least one of) the inputs. Read from the
    /// active wallet's labels (FN-Server labels each import "sp scan=<B_scan> …"), so no
    /// funding transactions are fetched; only older unlabeled `rawtr()` imports fall
    /// back to scanning their funding transaction. Completion on any queue.
    static func owner(of inputs: [Input], passphrase: String?, completion: @escaping (SilentPaymentSpend.ScanKeys?) -> Void) {
        // Only taproot inputs can be silent payment outputs.
        let candidates = inputs.filter { $0.kind == .p2tr }.map {
            SilentPaymentSpend.Candidate(txid: $0.txid, vout: $0.vout, outputKey: String($0.script.dropFirst(4)), info: nil)
        }

        SilentPaymentSpend.fillWalletInfo(candidates) { candidates in
            let mine = candidates.filter { $0.info?.isMine == true }
            let labeledScanKeys = Set(mine.flatMap { $0.info?.labels ?? [] }.compactMap { SilentPaymentSpend.WalletLabel($0)?.scanPub })
            let unlabeled = mine.filter { candidate in
                guard let info = candidate.info else { return false }
                return !info.labels.contains { SilentPaymentSpend.WalletLabel($0) != nil }
                    && (info.desc.hasPrefix("rawtr(") || info.desc.hasPrefix("addr("))
            }
            guard !labeledScanKeys.isEmpty || !unlabeled.isEmpty else {
                completion(nil)
                return
            }

            SilentPaymentSpend.scanKeyCandidates(passphrase: passphrase) { keys in
                // The signer whose scan key a label names. A separate copy is returned;
                // the candidates are wiped.
                if let key = keys.first(where: { SilentPaymentSpend.scanPublicKey(of: $0).map { labeledScanKeys.contains($0) } ?? false }) {
                    let copy = SilentPaymentSpend.ScanKeys(bScan: Data(Array(key.bScan)),
                                                          bSpendPub: key.bSpendPub,
                                                          signerLabel: key.signerLabel)
                    var keys = keys
                    for i in keys.indices { keys[i].bScan.secureZero() }
                    completion(copy)
                    return
                }

                // Older imports without the label: scan just their funding transactions.
                // `match` wipes the candidates and returns a copy of the owner's keys.
                let outpoints = unlabeled.map { (txid: $0.txid, vout: $0.vout) }
                SilentPaymentSpend.match(outpoints: outpoints, keys: keys, firstOnly: true, copyKeys: true) { matches in
                    completion(matches.first?.keys)
                }
            }
        }
    }

    /// P = B_spend + label_0·G + t_k·G for a transaction spending `inputs`, computed with
    /// b_scan exactly as a receiver scans (A = Σ eligible input keys, smallest outpoint
    /// over ALL inputs). k = 0 unless the same transaction already pays this scan key
    /// at k = 0.
    static func changeKey(inputs: [Input], keys: SilentPaymentSpend.ScanKeys, k: UInt32 = 0) throws -> Data {
        let pubkeys = try inputs.compactMap { $0.pubkey }.map {
            try P256K.Signing.PublicKey(dataRepresentation: $0, format: .compressed)
        }
        guard let first = pubkeys.first,
              let smallest = inputs.map({ $0.outpoint }).min(by: { $0.lexicographicallyPrecedes($1) }) else {
            throw WalletLogic.SPError("No inputs.")
        }
        // A = Σ input keys (throws if it's the point at infinity).
        let sum: P256K.Signing.PublicKey
        if pubkeys.count == 1 {
            sum = first
        } else {
            sum = try first.combine(Array(pubkeys.dropFirst()), format: .compressed)
        }
        let aSum = Data(sum.dataRepresentation)

        let inputHash = SPHashFN.tagged("BIP0352/Inputs", smallest + aSum)
        guard SPScalar.isValid(inputHash), SPScalar.isValid(keys.bScan) else {
            throw WalletLogic.SPError("Invalid input hash.")
        }
        // ecdh = (input_hash · b_scan) · A
        let ecdh = try sum.multiply(Array(keys.bScan), format: .compressed)
                          .multiply(Array(inputHash), format: .compressed)
        var kBE = k.bigEndian
        let tk = SPHashFN.tagged("BIP0352/SharedSecret", Data(ecdh.dataRepresentation) + Data(bytes: &kBE, count: 4))
        let label0 = SPHashFN.tagged("BIP0352/Label", keys.bScan + Data([0, 0, 0, 0]))
        guard SPScalar.isValid(tk), SPScalar.isValid(label0) else {
            throw WalletLogic.SPError("Invalid silent payment tweak.")
        }

        let bSpend = try P256K.Signing.PublicKey(dataRepresentation: keys.bSpendPub, format: .compressed)
        let p = try bSpend.add(Array(label0)).add(Array(tk))
        return Data(p.xonly.bytes)
    }

    /// Runs the receiver scan (the same code the verifier uses to detect silent payment
    /// inputs) on the transaction as it will be broadcast (key-path spends) and checks it
    /// finds the change as a label-0 output.
    static func selfCheck(tx: Tx, changeIndex: Int, finalScripts: [Int: String], keys: SilentPaymentSpend.ScanKeys) -> Bool {
        // Dummy signatures shaped like the real spends, so input eligibility is judged
        // exactly as on the broadcast transaction.
        let schnorrSig = String(repeating: "01", count: 64)
        let ecdsaSig = "30" + String(repeating: "01", count: 70)        // 71 bytes
        let vin: [[String: Any]] = tx.inputs.map { input in
            var entry: [String: Any] = ["txid": input.txid,
                                        "vout": NSNumber(value: input.vout),
                                        "prevout": ["scriptPubKey": ["hex": input.script]]]
            let pub = input.pubkey.map { SPHexFN.encode($0) } ?? ""
            switch input.kind {
            case .p2tr:
                entry["txinwitness"] = [schnorrSig]
            case .p2trNums:
                entry["txinwitness"] = [schnorrSig, "51", "c0" + SPDetect.numsH]
            case .p2wpkh:
                entry["txinwitness"] = [ecdsaSig, pub]
            case .p2shP2wpkh:
                let program = input.pubkey.map { SPHexFN.encode(SPHashFN.hash160($0)) } ?? ""
                entry["scriptSig"] = ["hex": "160014" + program]
                entry["txinwitness"] = [ecdsaSig, pub]
            case .p2pkh:
                entry["scriptSig"] = ["hex": "47" + ecdsaSig + "21" + pub]
            case .ineligible, .unknown, .segwitV2Plus:
                break
            }
            return entry
        }
        let vout: [[String: Any]] = tx.outputs.enumerated().map { i, out in
            ["n": NSNumber(value: i),
             "scriptPubKey": ["hex": finalScripts[i] ?? out.script]]
        }
        let owned = SilentPaymentSpend.scan(fundingTx: ["vin": vin, "vout": vout], txid: "", vout: changeIndex, keys: keys)
        return owned?.labelTweakHex != nil
    }
}
