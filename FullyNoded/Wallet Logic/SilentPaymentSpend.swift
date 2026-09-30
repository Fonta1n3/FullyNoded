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
            for dict in signers {
                let signer = SignerStruct(dictionary: dict)
                guard var encWords = signer.words,
                      var wordsData = Crypto.decrypt(encWords),
                      var words = wordsData.utf8String else { continue }
                defer {
                    wordsData.secureZero()
                    encWords.secureZero()
                    words.secureWipe()
                }

                // Candidate passphrases: typed, stored, none (de-duplicated).
                var candidates: [String] = [passphrase ?? ""]
                if let encPass = signer.passphrase, var passData = Crypto.decrypt(encPass), let p = passData.utf8String {
                    candidates.append(p)
                    passData.secureZero()
                }
                candidates.append("")
                var seen = Set<String>()

                for p in candidates where seen.insert(p).inserted {
                    guard var bSpend = spendKey(words: words, passphrase: p) else { continue }
                    defer { bSpend.secureZero() }
                    do {
                        let result = try sign(psbt: psbt, outputs: outputs, spendKey: bSpend)
                        done(result.psbt, result.signed, nil)
                        return
                    } catch let error as KeyMismatch {
                        // Wrong signer / passphrase: try the next one.
                        lastError = error.localizedDescription
                    } catch {
                        // A problem with the PSBT itself: no other key will fix it.
                        done(nil, 0, error.localizedDescription)
                        return
                    }
                }
            }
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

    // b_spend = m/352'/coin'/0'/0'/0 from a mnemonic (BIP352 key derivation).
    private static func spendKey(words: String, passphrase: String) -> Data? {
        guard let mnemonic = try? Mnemonic.fromString(mnemonic: words) else { return nil }
        let master = DescriptorSecretKey(networkKind: SPAddress.isMainnet ? .main : .test,
                                         mnemonic: mnemonic,
                                         password: passphrase.isEmpty ? nil : passphrase)
        let coin = SPAddress.isMainnet ? 0 : 1
        guard let path = try? BDKDerivationPathFN(path: "m/352h/\(coin)h/0h/0h/0"),
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
