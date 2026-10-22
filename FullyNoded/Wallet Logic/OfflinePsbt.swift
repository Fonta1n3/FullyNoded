//
//  OfflinePsbt.swift
//  FullyNoded
//
//  Reviews and signs a PSBT with one signer, entirely on this device: no node, no Esplora,
//  no Tor. Everything is checked from the PSBT itself and the signer's keys.
//
//  REVIEW (OfflinePsbt.analyze)
//  • Every input's amount and script come from its UTXO data. A full previous transaction
//    (non_witness_utxo) is hashed and must have the input's txid, and agree with witness_utxo.
//  • This signer's keys: each BIP32 derivation listed with its fingerprint is derived here
//    and must give the listed public key, and that key must actually be what the input's
//    script spends with: HASH160 for P2WPKH, the witness script's hash and contents for
//    P2WSH, the BIP341 output key for taproot (internal key + merkle root, or the leaf's
//    control block). A PSBT that lies about any of these is flagged, not signed.
//  • Change: an output claiming one of this signer's keys is verified the same way, so a
//    swapped "change" address can't hide as change.
//  • Fee from the input amounts (and an estimated size), sighash types, locktime, RBF.
//
//  SIGNING (OfflinePsbt.sign), P256K only:
//  • segwit v0 (P2WPKH, P2WSH, and both P2SH-wrapped): BIP143 sighash, ECDSA (RFC 6979,
//    low-S), PSBT_IN_PARTIAL_SIG.
//  • taproot key path: BIP341 sighash, key tweaked with the merkle root, Schnorr,
//    PSBT_IN_TAP_KEY_SIG. Script path: BIP341 (ext_flag 1) per leaf, PSBT_IN_TAP_SCRIPT_SIG.
//  • Every signature is verified before it's added. Only SIGHASH_ALL (and DEFAULT for
//    taproot). Legacy (non-segwit) inputs aren't signed.
//  BIP32 keys come from BDK's local key functions (no wallet, no network).
//

import Foundation
import CryptoKit
import P256K
import BitcoinDevKit

// MARK: - Keys

/// One signer's keys at BIP32 paths.
protocol OfflineKeySource {
    /// Master key fingerprint, 8 lowercase hex characters.
    var fingerprint: String { get }
    /// Whether `privateKey(at:)` can return keys (the seed words are present).
    var canSign: Bool { get }
    /// Compressed public key at `path`, if this source can derive it.
    func publicKey(at path: [UInt32]) -> Data?
    /// Private key at `path`, if this source has the seed.
    func privateKey(at path: [UInt32]) -> Data?
}

enum OfflineBIP32 {
    static let hardened: UInt32 = 0x8000_0000

    /// "m/84h/0h/0h/0/5"
    static func pathString(_ path: [UInt32]) -> String {
        "m" + path.map { "/\($0 & ~hardened)" + ($0 >= hardened ? "h" : "") }.joined()
    }
}

/// Keys from the signer's seed words (and passphrase).
final class OfflineSeedKeys: OfflineKeySource {
    let fingerprint: String
    let canSign = true
    private let master: DescriptorSecretKey

    /// nil if the words aren't a valid mnemonic.
    init?(words: String, passphrase: String) {
        guard let mnemonic = try? Mnemonic.fromString(mnemonic: words) else { return nil }
        master = DescriptorSecretKey(networkKind: .main, mnemonic: mnemonic, password: passphrase.isEmpty ? nil : passphrase)
        guard let pub = try? P256K.Signing.PrivateKey(dataRepresentation: master.secretBytes()).publicKey else { return nil }
        fingerprint = SPHexFN.encode(SPHashFN.hash160(pub.dataRepresentation).prefix(4))
    }

    func privateKey(at path: [UInt32]) -> Data? {
        guard let derivationPath = try? BDKDerivationPathFN(path: OfflineBIP32.pathString(path)),
              let child = try? master.derive(path: derivationPath) else { return nil }
        return child.secretBytes()
    }

    func publicKey(at path: [UInt32]) -> Data? {
        guard var secret = privateKey(at: path) else { return nil }
        defer { secret.secureZero() }
        return (try? P256K.Signing.PrivateKey(dataRepresentation: secret))?.publicKey.dataRepresentation
    }
}

/// Keys from a signer whose words were deleted: its saved account xpubs (BIP84, BIP86 and
/// BIP48 script type 2, mainnet and testnet). Public keys only, for paths under those accounts.
final class OfflineWatchKeys: OfflineKeySource {
    let fingerprint: String
    let canSign = false
    /// Account path → "[xfp/path]xpub" key expression.
    private let accounts: [(path: [UInt32], key: String)]

    init(fingerprint: String, accounts: [(path: [UInt32], xpub: String)]) {
        self.fingerprint = fingerprint.lowercased()
        self.accounts = accounts.map { account in
            let origin = OfflineBIP32.pathString(account.path).dropFirst()   // "/84h/0h/0h"
            return (account.path, "[\(fingerprint.lowercased())\(origin)]\(account.xpub)")
        }
    }

    func privateKey(at path: [UInt32]) -> Data? { nil }

    func publicKey(at path: [UInt32]) -> Data? {
        for account in accounts where path.count > account.path.count && Array(path.prefix(account.path.count)) == account.path {
            let rest = Array(path.dropFirst(account.path.count))
            guard !rest.contains(where: { $0 >= OfflineBIP32.hardened }),
                  let key = try? DescriptorPublicKey.fromString(publicKey: account.key),
                  let derivationPath = try? BDKDerivationPathFN(path: OfflineBIP32.pathString(rest)),
                  let child = try? key.derive(path: derivationPath),
                  let payload = Keys.extendedKeyPayload(Keys.plainExtendedKey(child.description)),
                  payload.key.count == 33 else { continue }
            return payload.key
        }
        return nil
    }
}

// MARK: - Review

enum OfflinePsbt {

    enum Severity: Int, Comparable {
        case ok, info, warning, danger
        static func < (a: Severity, b: Severity) -> Bool { a.rawValue < b.rawValue }
    }

    struct Note {
        let severity: Severity
        let text: String
    }

    enum ScriptType: String {
        case p2wpkh = "P2WPKH", p2shP2wpkh = "P2SH-P2WPKH", p2wsh = "P2WSH", p2shP2wsh = "P2SH-P2WSH"
        case p2tr = "Taproot", p2pkh = "P2PKH (legacy)", p2sh = "P2SH", unknown = "Unknown script"
    }

    /// A signature this signer can add, with everything signing needs (already verified).
    enum Job {
        /// Segwit v0: BIP143 with this script code.
        case ecdsa(pubkey: Data, path: [UInt32], scriptCode: Data)
        /// Taproot key path: the internal key's private key, tweaked with the merkle root.
        case taprootKey(xonly: Data, path: [UInt32], merkleRoot: Data?)
        /// Taproot script path, one per leaf the key appears in.
        case taprootScript(xonly: Data, path: [UInt32], leafHash: Data)
    }

    struct InputReport {
        let index: Int
        let outpoint: String
        let amount: UInt64?
        let scriptType: ScriptType
        let address: String?
        var notes: [Note] = []
        /// Signatures this signer can still add.
        var jobs: [Job] = []
        /// This signer's signatures already in the PSBT.
        var signedByUs = 0
        /// Signatures from anyone (partial, taproot key / script path).
        var signatures = 0
        var finalized = false
        var involvesUs: Bool { !jobs.isEmpty || signedByUs > 0 }
        var severity: Severity { notes.map(\.severity).max() ?? .ok }
    }

    enum OutputKind { case change, external, badChange }

    struct OutputReport {
        let index: Int
        let amount: UInt64
        let scriptType: ScriptType
        let address: String?
        let kind: OutputKind
        var notes: [Note] = []
    }

    struct Report {
        let inputs: [InputReport]
        let outputs: [OutputReport]
        let totalIn: UInt64?
        let totalOut: UInt64
        let fee: Int64?
        /// Estimated once fully signed.
        let vsize: Int
        let locktime: UInt32
        let rbf: Bool
        let mainnet: Bool
        let notes: [Note]
        /// The signer's master fingerprint the review used.
        let fingerprint: String

        var feeRate: Double? { fee.map { Double($0) / Double(max(vsize, 1)) } }
        var signable: Int { inputs.reduce(0) { $0 + $1.jobs.count } }
        var involvesUs: Bool { inputs.contains(where: \.involvesUs) }
        /// The worst thing found anywhere.
        var verdict: Severity {
            (notes.map(\.severity) + inputs.map(\.severity) + outputs.flatMap { $0.notes.map(\.severity) }).max() ?? .ok
        }
        /// External outputs: what this transaction actually sends.
        var sending: UInt64 { outputs.filter { $0.kind != .change }.reduce(0) { $0 + $1.amount } }
    }

    struct PsbtError: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }

    // MARK: Decoding

    /// base64 or hex text, or raw binary (a .psbt file).
    static func decode(_ data: Data) -> Data? {
        if data.starts(with: [0x70, 0x73, 0x62, 0x74, 0xFF]) { return data }
        guard let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        return decode(text)
    }

    static func decode(_ text: String) -> Data? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw = Data(base64Encoded: trimmed), raw.starts(with: [0x70, 0x73, 0x62, 0x74, 0xFF]) { return raw }
        if trimmed.lowercased().hasPrefix("70736274ff"), let raw = SPHexFN.decode(trimmed.lowercased()) { return raw }
        return nil
    }

    /// Every master fingerprint the PSBT's inputs and outputs mention.
    static func fingerprints(in raw: Data) -> [String] {
        guard let psbt = try? SPPsbt(raw) else { return [] }
        return (psbt.inputs + psbt.outputs).flatMap { origins(in: $0).map(\.fingerprint) }
    }

    // MARK: Analyze

    static func analyze(_ raw: Data, keys: OfflineKeySource) throws -> Report {
        let psbt = try SPPsbt(raw)
        let tx = psbt.tx
        let ourFingerprint = keys.fingerprint.lowercased()

        // Network from this signer's derivation paths (coin type), else from the app.
        var coinTypes = Set<UInt32>()
        for map in psbt.inputs + psbt.outputs {
            for origin in origins(in: map) where origin.fingerprint == ourFingerprint && origin.path.count > 1 {
                coinTypes.insert(origin.path[1] & ~OfflineBIP32.hardened)
            }
        }
        let mainnet = coinTypes.isEmpty ? (UserDefaults.standard.string(forKey: "chain") ?? "main") == "main" : coinTypes.contains(0)
        let network: BitcoinDevKit.Network = mainnet ? .bitcoin : ((UserDefaults.standard.string(forKey: "chain") == "regtest") ? .regtest : .testnet)

        var notes: [Note] = []
        var inputs: [InputReport] = []
        var prevouts: [SPTx.Output?] = []

        for (i, txin) in tx.inputs.enumerated() {
            let map = psbt.inputs[i]
            var notesHere: [Note] = []
            let witnessUtxo = value(map, [0x01]).flatMap { try? readOutput($0) }
            var prevout = witnessUtxo

            // Full previous transaction: must hash to this input's txid.
            if let nwu = value(map, [0x00]) {
                if let prevTx = try? SPTx(nwu), let txid = try? txidInternal(nwu) {
                    if txid != Array(txin.outpoint[0..<32]) {
                        notesHere.append(Note(severity: .danger, text: "The previous transaction included for this input isn't the one it spends (txid mismatch)."))
                    } else if Int(txin.vout) >= prevTx.outputs.count {
                        notesHere.append(Note(severity: .danger, text: "The previous transaction has no output #\(txin.vout)."))
                    } else {
                        let spent = prevTx.outputs[Int(txin.vout)]
                        if let w = witnessUtxo, w.serialized != spent.serialized {
                            notesHere.append(Note(severity: .danger, text: "witness_utxo disagrees with the previous transaction about this input's amount or script."))
                        }
                        prevout = spent
                        notesHere.append(Note(severity: .ok, text: "Amount verified against the full previous transaction."))
                    }
                } else {
                    notesHere.append(Note(severity: .danger, text: "The previous transaction included for this input can't be parsed."))
                }
            }

            guard let utxo = prevout else {
                prevouts.append(nil)
                inputs.append(InputReport(index: i, outpoint: "\(txin.txidDisplay):\(txin.vout)", amount: nil, scriptType: .unknown, address: nil,
                                          notes: notesHere + [Note(severity: .danger, text: "No UTXO data: this input's amount and script are unknown, so it can't be checked or signed.")]))
                continue
            }
            prevouts.append(utxo)

            let spk = [UInt8](utxo.script)
            let redeem = value(map, [0x04])
            let witnessScript = value(map, [0x05])
            let type = scriptType(spk: spk, redeem: redeem)
            var report = InputReport(index: i, outpoint: "\(txin.txidDisplay):\(txin.vout)", amount: amount(utxo), scriptType: type,
                                     address: address(spk, network), notes: notesHere)

            // Already final, and signatures present.
            report.finalized = value(map, [0x07]) != nil || value(map, [0x08]) != nil
            let partials = map.filter { $0.key.first == 0x02 && $0.key.count == 34 }
            report.signatures = partials.count + map.filter { $0.key == [0x13] || ($0.key.first == 0x14 && $0.key.count == 65) }.count

            // Sighash type.
            let sighash = value(map, [0x03]).flatMap { $0.count == 4 ? UInt32($0[0]) | UInt32($0[1]) << 8 | UInt32($0[2]) << 16 | UInt32($0[3]) << 24 : nil }
            if let sighash, !(sighash == 1 || (sighash == 0 && type == .p2tr)) {
                report.notes.append(Note(severity: .danger, text: "Asks for sighash type \(sighash), which can let others change the transaction after you sign. Only ALL is signed here."))
            }

            if type == .p2wpkh || type == .p2wsh || type == .p2shP2wpkh || type == .p2shP2wsh, value(map, [0x00]) == nil {
                report.notes.append(Note(severity: .warning, text: "Segwit v0 input without its full previous transaction: its amount can't be verified offline. Sign only if you trust where this PSBT came from."))
            }

            if type == .p2pkh || type == .p2sh || type == .unknown {
                if origins(in: map).contains(where: { $0.fingerprint == ourFingerprint }) {
                    report.notes.append(Note(severity: .warning, text: "Uses this signer's key, but \(type.rawValue) inputs aren't signed here (segwit and taproot only)."))
                }
            } else if !report.finalized {
                checkOurKeys(input: &report, map: map, spk: spk, redeem: redeem, witnessScript: witnessScript, keys: keys, partials: partials)
            }
            inputs.append(report)
        }

        // Outputs.
        var outputs: [OutputReport] = []
        for (o, txout) in tx.outputs.enumerated() {
            let spk = [UInt8](txout.script)
            let map = psbt.outputs[o]
            let type = scriptType(spk: spk, redeem: value(map, [0x00]))
            let (kind, outputNotes) = classifyOutput(map: map, spk: spk, type: type, keys: keys)
            var report = OutputReport(index: o, amount: amount(txout), scriptType: type, address: address(spk, network), kind: kind, notes: outputNotes)
            if spk.first == 0x6A {
                report.notes.append(Note(severity: .info, text: "OP_RETURN data output."))
            } else if report.amount < 546 {
                report.notes.append(Note(severity: .warning, text: "Dust output (\(report.amount) sats): it may not relay."))
            }
            outputs.append(report)
        }

        // Totals and fee.
        let totalOut = outputs.reduce(UInt64(0)) { $0 + $1.amount }
        let known = prevouts.compactMap { $0 }
        let totalIn: UInt64? = known.count == prevouts.count ? known.reduce(UInt64(0)) { $0 + amount($1) } : nil
        let fee = totalIn.map { Int64(bitPattern: $0) - Int64(bitPattern: totalOut) }
        let vsize = estimateVsize(psbt: psbt, inputs: inputs)

        if let fee {
            if fee < 0 {
                notes.append(Note(severity: .danger, text: "The outputs add up to more than the inputs: this transaction is invalid."))
            } else {
                let rate = Double(fee) / Double(max(vsize, 1))
                if rate > 500 || (totalOut > 0 && Double(fee) > Double(totalOut) * 0.1 && fee > 50_000) {
                    notes.append(Note(severity: .warning, text: "Very high fee: \(fee) sats (≈\(Int(rate)) sat/vB)."))
                } else if rate < 1 {
                    notes.append(Note(severity: .warning, text: "Fee rate below 1 sat/vB: it may not relay."))
                }
            }
        } else {
            notes.append(Note(severity: .warning, text: "Some input amounts are unknown, so the fee can't be worked out."))
        }

        let locktime = UInt32(tx.locktime[0]) | UInt32(tx.locktime[1]) << 8 | UInt32(tx.locktime[2]) << 16 | UInt32(tx.locktime[3]) << 24
        let rbf = tx.inputs.contains { input in
            let s = UInt32(input.sequence[0]) | UInt32(input.sequence[1]) << 8 | UInt32(input.sequence[2]) << 16 | UInt32(input.sequence[3]) << 24
            return s < 0xFFFF_FFFE
        }

        if !inputs.contains(where: \.involvesUs) {
            let unknownToWatch = !keys.canSign && inputs.contains { input in
                origins(in: psbt.inputs[input.index]).contains { $0.fingerprint == ourFingerprint }
            }
            notes.append(Note(severity: .warning, text: unknownToWatch
                ? "This signer's key is in the PSBT, but without the seed words it can only check BIP84, BIP86 and BIP48 (P2WSH) account keys."
                : "None of the inputs use this signer's keys (fingerprint \(ourFingerprint)), so it has nothing to sign."))
        }

        return Report(inputs: inputs, outputs: outputs, totalIn: totalIn, totalOut: totalOut, fee: fee, vsize: vsize,
                      locktime: locktime, rbf: rbf, mainnet: mainnet, notes: notes, fingerprint: ourFingerprint)
    }

    /// Finds this signer's keys in the input, checks each against the derivation and the
    /// script, and records what can be signed.
    private static func checkOurKeys(input report: inout InputReport, map: [SPPsbt.Entry], spk: [UInt8], redeem: [UInt8]?,
                                     witnessScript: [UInt8]?, keys: OfflineKeySource, partials: [SPPsbt.Entry]) {
        let ourFingerprint = keys.fingerprint.lowercased()

        // Segwit v0 / legacy: PSBT_IN_BIP32_DERIVATION.
        for entry in map where entry.key.first == 0x06 && entry.key.count == 34 {
            guard let origin = keyOrigin(entry.value), origin.fingerprint == ourFingerprint else { continue }
            let pubkey = Data(entry.key.dropFirst())
            let pathText = OfflineBIP32.pathString(origin.path)
            guard let derived = keys.publicKey(at: origin.path) else {
                report.notes.append(Note(severity: .warning, text: "Can't check key \(pathText) without the seed words."))
                continue
            }
            guard derived == pubkey else {
                report.notes.append(Note(severity: .danger, text: "The key listed at \(pathText) isn't this signer's key at that path. The PSBT is lying about it."))
                continue
            }
            guard let scriptCode = segwitScriptCode(for: pubkey, spk: spk, redeem: redeem, witnessScript: witnessScript) else {
                report.notes.append(Note(severity: .danger, text: "This signer's key (\(pathText)) isn't what this input's script spends with."))
                continue
            }
            if partials.contains(where: { Data($0.key.dropFirst()) == pubkey }) {
                report.signedByUs += 1
            } else {
                report.jobs.append(.ecdsa(pubkey: pubkey, path: origin.path, scriptCode: scriptCode))
            }
            report.notes.append(Note(severity: .ok, text: "This signer's key \(pathText) verified against the script."))
        }

        // Taproot: PSBT_IN_TAP_BIP32_DERIVATION.
        guard spk.count == 34, spk[0] == 0x51, spk[1] == 0x20 else { return }
        let outputKey = Array(spk[2...])
        let internalKey = value(map, [0x17])
        let merkleRoot = value(map, [0x18])
        let leafScripts = tapLeafScripts(map)

        for entry in map where entry.key.first == 0x16 && entry.key.count == 33 {
            guard let (leafHashes, origin) = tapKeyOrigin(entry.value), origin.fingerprint == ourFingerprint else { continue }
            let xonly = Data(entry.key.dropFirst())
            let pathText = OfflineBIP32.pathString(origin.path)
            guard let derived = keys.publicKey(at: origin.path) else {
                report.notes.append(Note(severity: .warning, text: "Can't check taproot key \(pathText) without the seed words."))
                continue
            }
            guard Data(derived.dropFirst()) == xonly else {
                report.notes.append(Note(severity: .danger, text: "The taproot key listed at \(pathText) isn't this signer's key at that path. The PSBT is lying about it."))
                continue
            }

            if leafHashes.isEmpty {
                // Key path: our key is the internal key, tweaked into the output key.
                guard let internalKey, Data(internalKey) == xonly,
                      tweakedKey(internalKey: internalKey, merkleRoot: merkleRoot)?.bytes == outputKey else {
                    report.notes.append(Note(severity: .danger, text: "This signer's taproot key (\(pathText)) doesn't produce this input's output key."))
                    continue
                }
                if value(map, [0x13]) != nil {
                    report.signedByUs += 1
                } else {
                    report.jobs.append(.taprootKey(xonly: xonly, path: origin.path, merkleRoot: merkleRoot.map { Data($0) }))
                }
                report.notes.append(Note(severity: .ok, text: "This signer's taproot key \(pathText) verified against the output key."))
            }

            for leafHash in leafHashes {
                guard let leaf = leafScripts.first(where: { $0.leafHash == leafHash }) else {
                    report.notes.append(Note(severity: .warning, text: "The PSBT doesn't include the script for one of this key's taproot leaves."))
                    continue
                }
                guard contains(leaf.script, push: [UInt8](xonly)) else {
                    report.notes.append(Note(severity: .danger, text: "A taproot leaf listed for this signer's key (\(pathText)) doesn't contain it."))
                    continue
                }
                guard controlBlockCommits(leaf.controlBlock, leafHash: leafHash, outputKey: outputKey) else {
                    report.notes.append(Note(severity: .danger, text: "The taproot leaf for \(pathText) isn't committed to by this input's output key."))
                    continue
                }
                let signed = map.contains { $0.key == [0x14] + [UInt8](xonly) + leafHash }
                if signed {
                    report.signedByUs += 1
                } else {
                    report.jobs.append(.taprootScript(xonly: xonly, path: origin.path, leafHash: Data(leafHash)))
                }
                report.notes.append(Note(severity: .ok, text: "This signer's taproot key \(pathText) verified in a script leaf."))
            }
        }
    }

    /// Change: an output with one of this signer's keys must actually pay to it.
    private static func classifyOutput(map: [SPPsbt.Entry], spk: [UInt8], type: ScriptType, keys: OfflineKeySource) -> (OutputKind, [Note]) {
        let ourFingerprint = keys.fingerprint.lowercased()
        var claimed = false
        var verified = false
        var unverifiable = false

        for entry in map where entry.key.first == 0x02 && entry.key.count == 34 {
            guard let origin = keyOrigin(entry.value), origin.fingerprint == ourFingerprint else { continue }
            claimed = true
            let pubkey = Data(entry.key.dropFirst())
            guard let derived = keys.publicKey(at: origin.path) else { unverifiable = true; continue }
            if derived == pubkey, segwitScriptCode(for: pubkey, spk: spk, redeem: value(map, [0x00]), witnessScript: value(map, [0x01])) != nil {
                verified = true
            }
        }

        for entry in map where entry.key.first == 0x07 && entry.key.count == 33 {
            guard let (leafHashes, origin) = tapKeyOrigin(entry.value), origin.fingerprint == ourFingerprint else { continue }
            claimed = true
            let xonly = [UInt8](entry.key.dropFirst())
            guard let derived = keys.publicKey(at: origin.path) else { unverifiable = true; continue }
            guard [UInt8](derived.dropFirst()) == xonly, spk.count == 34, spk[0] == 0x51 else { continue }
            let internalKey = value(map, [0x05])
            let root = value(map, [0x06]).flatMap(tapTreeRoot)
            guard let internalKey, tweakedKey(internalKey: internalKey, merkleRoot: root)?.bytes == Array(spk[2...]) else { continue }
            if leafHashes.isEmpty {
                if internalKey == xonly { verified = true }
            } else if let tree = value(map, [0x06]), let leaves = tapTreeLeafHashes(tree) {
                if leafHashes.allSatisfy({ leaves.contains($0) }) { verified = true }
            }
        }

        if !claimed { return (.external, []) }
        if verified { return (.change, [Note(severity: .ok, text: "Change back to this signer, verified.")]) }
        if unverifiable { return (.external, [Note(severity: .info, text: "Claims to be change, but without the seed words this signer can't check it.")]) }
        return (.badChange, [Note(severity: .danger, text: "Claims to be change to this signer, but the address isn't derived from its keys. Treat it as a payment to someone else.")])
    }

    // MARK: Sign

    /// Adds this signer's signatures. Refuses if the review found anything dangerous.
    static func sign(_ raw: Data, keys: OfflineKeySource) throws -> (psbt: Data, added: Int) {
        guard keys.canSign else { throw PsbtError("This signer has no seed words, so it can't sign.") }
        let report = try analyze(raw, keys: keys)
        guard report.verdict != .danger else { throw PsbtError("This PSBT failed its checks, so it wasn't signed.") }
        var psbt = try SPPsbt(raw)
        let tx = psbt.tx

        let prevouts = try tx.inputs.indices.map { try psbt.prevout(input: $0) }
        var added = 0

        for input in report.inputs where !input.jobs.isEmpty {
            let i = input.index
            let hashType: UInt8 = value(psbt.inputs[i], [0x03]).map { $0[0] } ?? (input.scriptType == .p2tr ? 0x00 : 0x01)

            for job in input.jobs {
                switch job {
                case let .ecdsa(pubkey, path, scriptCode):
                    guard var secret = keys.privateKey(at: path) else { throw PsbtError("Couldn't derive \(OfflineBIP32.pathString(path)).") }
                    defer { secret.secureZero() }
                    let key = try P256K.Signing.PrivateKey(dataRepresentation: secret)
                    guard key.publicKey.dataRepresentation == pubkey else { throw PsbtError("Derived key mismatch on input \(i).") }
                    let digest = HashDigest([UInt8](bip143Sighash(tx: tx, index: i, scriptCode: scriptCode, amount: prevouts[i].amount, hashType: UInt32(hashType))))
                    let signature = key.signature(for: digest)
                    guard key.publicKey.isValidSignature(signature, for: digest) else { throw PsbtError("Signature for input \(i) failed verification.") }
                    let der = try signature.derRepresentation
                    psbt.inputs[i].append((key: [0x02] + [UInt8](pubkey), value: [UInt8](der) + [hashType]))
                    added += 1

                case let .taprootKey(xonly, path, merkleRoot):
                    guard var secret = keys.privateKey(at: path) else { throw PsbtError("Couldn't derive \(OfflineBIP32.pathString(path)).") }
                    defer { secret.secureZero() }
                    let key = try P256K.Schnorr.PrivateKey(dataRepresentation: secret)
                    guard Data(key.xonly.bytes) == xonly else { throw PsbtError("Derived key mismatch on input \(i).") }
                    let tweak = SPHashFN.tagged("TapTweak", xonly + (merkleRoot ?? Data()))
                    let tweaked = try key.add([UInt8](tweak))
                    guard tweaked.xonly.bytes == Array(prevouts[i].script.dropFirst(2)) else { throw PsbtError("Tweaked key doesn't match input \(i).") }
                    var message = [UInt8](try SPSighash.taprootKeyPath(tx: tx, prevouts: prevouts, inputIndex: i, hashType: hashType))
                    let signature = try schnorrSign(tweaked, &message)
                    psbt.inputs[i].append((key: [0x13], value: [UInt8](signature) + (hashType == 0 ? [] : [hashType])))
                    added += 1

                case let .taprootScript(xonly, path, leafHash):
                    guard var secret = keys.privateKey(at: path) else { throw PsbtError("Couldn't derive \(OfflineBIP32.pathString(path)).") }
                    defer { secret.secureZero() }
                    let key = try P256K.Schnorr.PrivateKey(dataRepresentation: secret)
                    guard Data(key.xonly.bytes) == xonly else { throw PsbtError("Derived key mismatch on input \(i).") }
                    var message = [UInt8](try taprootScriptSighash(tx: tx, prevouts: prevouts, index: i, leafHash: leafHash, hashType: hashType))
                    let signature = try schnorrSign(key, &message)
                    psbt.inputs[i].append((key: [0x14] + [UInt8](xonly) + [UInt8](leafHash), value: [UInt8](signature) + (hashType == 0 ? [] : [hashType])))
                    added += 1
                }
            }
        }
        return (psbt.serialize(), added)
    }

    /// BIP340 signature with fresh auxiliary randomness, verified before it's returned.
    private static func schnorrSign(_ key: P256K.Schnorr.PrivateKey, _ message: inout [UInt8]) throws -> Data {
        guard var aux = Crypto.secret(), aux.count == 32 else { throw PsbtError("No randomness available.") }
        defer { aux.secureZero() }
        let signature = try aux.withUnsafeMutableBytes { try key.signature(message: &message, auxiliaryRand: $0.baseAddress, strict: true) }
        guard key.xonly.isValid(signature, for: &message) else { throw PsbtError("A taproot signature failed verification.") }
        return signature.dataRepresentation
    }

    // MARK: Sighashes

    /// BIP143 (segwit v0) signature hash for SIGHASH_ALL.
    static func bip143Sighash(tx: SPTx, index: Int, scriptCode: Data, amount: [UInt8], hashType: UInt32) -> Data {
        func dsha(_ b: [UInt8]) -> [UInt8] { [UInt8](SHA256.hash(data: [UInt8](SHA256.hash(data: b)))) }
        var preimage = tx.version
        preimage += dsha(tx.inputs.flatMap { $0.outpoint })
        preimage += dsha(tx.inputs.flatMap { $0.sequence })
        preimage += tx.inputs[index].outpoint
        preimage += [UInt8](scriptCode)
        preimage += amount
        preimage += tx.inputs[index].sequence
        preimage += dsha(tx.outputs.flatMap { $0.serialized })
        preimage += tx.locktime
        preimage += SPWriter.le32(hashType)
        return Data(dsha(preimage))
    }

    /// BIP341 script-path signature hash (ext_flag 1, key_version 0, no code separator).
    static func taprootScriptSighash(tx: SPTx, prevouts: [SPTx.Output], index: Int, leafHash: Data, hashType: UInt8) throws -> Data {
        guard hashType == 0x00 || hashType == 0x01 else { throw PsbtError("Unsupported sighash type.") }
        func sha(_ b: [UInt8]) -> [UInt8] { [UInt8](SHA256.hash(data: b)) }
        var msg: [UInt8] = [0x00, hashType]
        msg += tx.version
        msg += tx.locktime
        msg += sha(tx.inputs.flatMap { $0.outpoint })
        msg += sha(prevouts.flatMap { $0.amount })
        msg += sha(prevouts.flatMap { SPWriter.compactSize($0.script.count) + [UInt8]($0.script) })
        msg += sha(tx.inputs.flatMap { $0.sequence })
        msg += sha(tx.outputs.flatMap { $0.serialized })
        msg.append(0x02)                                  // spend_type: ext_flag 1, no annex
        msg += SPWriter.le32(UInt32(index))
        msg += [UInt8](leafHash)
        msg.append(0x00)                                  // key_version
        msg += [0xFF, 0xFF, 0xFF, 0xFF]                   // codesep_pos: none
        return SPHashFN.tagged("TapSighash", Data(msg))
    }

    // MARK: Script checks

    static func scriptType(spk: [UInt8], redeem: [UInt8]?) -> ScriptType {
        switch spk.count {
        case 22 where spk[0] == 0x00 && spk[1] == 0x14: return .p2wpkh
        case 34 where spk[0] == 0x00 && spk[1] == 0x20: return .p2wsh
        case 34 where spk[0] == 0x51 && spk[1] == 0x20: return .p2tr
        case 25 where spk[0] == 0x76 && spk[1] == 0xA9 && spk[2] == 0x14 && spk[23] == 0x88 && spk[24] == 0xAC: return .p2pkh
        case 23 where spk[0] == 0xA9 && spk[1] == 0x14 && spk[22] == 0x87:
            if let redeem, redeem.count == 22, redeem[0] == 0x00, redeem[1] == 0x14 { return .p2shP2wpkh }
            if let redeem, redeem.count == 34, redeem[0] == 0x00, redeem[1] == 0x20 { return .p2shP2wsh }
            return .p2sh
        default: return .unknown
        }
    }

    /// The BIP143 script code if `pubkey` is really what the segwit v0 script spends with, else nil.
    static func segwitScriptCode(for pubkey: Data, spk: [UInt8], redeem: [UInt8]?, witnessScript: [UInt8]?) -> Data? {
        let hash160 = [UInt8](SPHashFN.hash160(pubkey))
        let p2wpkh: [UInt8] = [0x00, 0x14] + hash160
        let p2pkhCode: [UInt8] = [0x19, 0x76, 0xA9, 0x14] + hash160 + [0x88, 0xAC]

        func p2sh(_ script: [UInt8]) -> [UInt8] { [0xA9, 0x14] + [UInt8](SPHashFN.hash160(Data(script))) + [0x87] }
        func witnessProgram(_ ws: [UInt8]) -> [UInt8] { [0x00, 0x20] + [UInt8](SHA256.hash(data: ws)) }

        // P2WPKH, native or wrapped.
        if spk == p2wpkh || (redeem == p2wpkh && spk == p2sh(p2wpkh)) { return Data(p2pkhCode) }

        // P2WSH, native or wrapped: the witness script must hash to the program and contain the key.
        if let ws = witnessScript, contains(ws, push: [UInt8](pubkey)) {
            let program = witnessProgram(ws)
            if spk == program || (redeem == program && spk == p2sh(program)) {
                return Data(SPWriter.compactSize(ws.count) + ws)
            }
        }
        return nil
    }

    /// Whether `script` pushes exactly `data` (a 33-byte key or 32-byte x-only key).
    static func contains(_ script: [UInt8], push data: [UInt8]) -> Bool {
        pushes(script).contains(data)
    }

    /// The data pushes of a script, in order.
    static func pushes(_ script: [UInt8]) -> [[UInt8]] {
        var result: [[UInt8]] = []
        var i = 0
        while i < script.count {
            let op = Int(script[i])
            var length = 0, header = 1
            switch op {
            case 1...75: length = op
            case 0x4C where i + 1 < script.count: length = Int(script[i + 1]); header = 2
            case 0x4D where i + 2 < script.count: length = Int(script[i + 1]) | Int(script[i + 2]) << 8; header = 3
            default:
                i += 1
                continue
            }
            guard i + header + length <= script.count else { break }
            result.append(Array(script[(i + header)..<(i + header + length)]))
            i += header + length
        }
        return result
    }

    // MARK: Taproot

    /// BIP341: Q = P + hash_TapTweak(P || root)·G, P the even-Y lift of `internal`.
    static func tweakedKey(internalKey: [UInt8], merkleRoot: [UInt8]?) -> P256K.Schnorr.XonlyKey? {
        guard internalKey.count == 32 else { return nil }
        let tweak = SPHashFN.tagged("TapTweak", Data(internalKey + (merkleRoot ?? [])))
        return try? P256K.Schnorr.XonlyKey(dataRepresentation: internalKey, keyParity: 0).add([UInt8](tweak))
    }

    static func tapLeafHash(script: [UInt8], leafVersion: UInt8) -> [UInt8] {
        [UInt8](SPHashFN.tagged("TapLeaf", Data([leafVersion] + SPWriter.compactSize(script.count) + script)))
    }

    static func tapBranch(_ a: [UInt8], _ b: [UInt8]) -> [UInt8] {
        let (lo, hi) = a.lexicographicallyPrecedes(b) ? (a, b) : (b, a)
        return [UInt8](SPHashFN.tagged("TapBranch", Data(lo + hi)))
    }

    /// The control block's internal key and path, hashed up from the leaf, must give the
    /// output key with the parity it states.
    static func controlBlockCommits(_ controlBlock: [UInt8], leafHash: [UInt8], outputKey: [UInt8]) -> Bool {
        guard controlBlock.count >= 33, (controlBlock.count - 33) % 32 == 0 else { return false }
        let internalKey = Array(controlBlock[1..<33])
        var node = leafHash
        for start in stride(from: 33, to: controlBlock.count, by: 32) {
            node = tapBranch(node, Array(controlBlock[start..<start + 32]))
        }
        guard let q = tweakedKey(internalKey: internalKey, merkleRoot: node) else { return false }
        return q.bytes == outputKey && q.parity == (controlBlock[0] & 1 == 1)
    }

    /// PSBT_IN_TAP_LEAF_SCRIPT entries: control block → script, leaf version.
    private static func tapLeafScripts(_ map: [SPPsbt.Entry]) -> [(controlBlock: [UInt8], script: [UInt8], leafHash: [UInt8])] {
        map.compactMap { entry in
            guard entry.key.first == 0x15, entry.key.count >= 34, let leafVersion = entry.value.last else { return nil }
            let controlBlock = Array(entry.key.dropFirst())
            let script = Array(entry.value.dropLast())
            guard controlBlock[0] & 0xFE == leafVersion else { return nil }
            return (controlBlock, script, tapLeafHash(script: script, leafVersion: leafVersion))
        }
    }

    /// PSBT_OUT_TAP_TREE (depth, leaf version, script)* in depth-first order → leaves and root.
    private static func tapTreeLeaves(_ tree: [UInt8]) -> [(depth: Int, hash: [UInt8])]? {
        var reader = SPReader(tree)
        var leaves: [(Int, [UInt8])] = []
        while !reader.atEnd {
            guard let depth = try? reader.bytes(1)[0], let version = try? reader.bytes(1)[0],
                  let length = try? reader.compactSize(), let script = try? reader.bytes(length) else { return nil }
            leaves.append((Int(depth), tapLeafHash(script: script, leafVersion: version)))
        }
        return leaves
    }

    static func tapTreeLeafHashes(_ tree: [UInt8]) -> [[UInt8]]? {
        tapTreeLeaves(tree)?.map(\.hash)
    }

    static func tapTreeRoot(_ tree: [UInt8]) -> [UInt8]? {
        guard let leaves = tapTreeLeaves(tree), !leaves.isEmpty else { return nil }
        // Combine siblings at the deepest level until one node at depth 0 remains.
        var stack: [(depth: Int, hash: [UInt8])] = []
        for leaf in leaves {
            stack.append(leaf)
            while stack.count >= 2, stack[stack.count - 1].depth == stack[stack.count - 2].depth, stack[stack.count - 1].depth > 0 {
                let right = stack.removeLast()
                let left = stack.removeLast()
                stack.append((right.depth - 1, tapBranch(left.hash, right.hash)))
            }
        }
        guard stack.count == 1, stack[0].depth == 0 else { return nil }
        return stack[0].hash
    }

    // MARK: Size

    /// vsize once signed: the unsigned transaction plus a witness estimate per input.
    private static func estimateVsize(psbt: SPPsbt, inputs: [InputReport]) -> Int {
        let baseSize = psbt.global.first { $0.key == [0x00] }?.value.count ?? 0
        var witness = 2   // marker + flag
        var extraBase = 0
        for input in inputs {
            let map = psbt.inputs[input.index]
            let ws = value(map, [0x05])
            switch input.scriptType {
            case .p2wpkh: witness += 108
            case .p2shP2wpkh: witness += 108; extraBase += 23
            case .p2wsh, .p2shP2wsh:
                let script = ws ?? []
                let m = max(1, Int(script.first ?? 0x51) - 0x50)
                witness += 1 + 1 + m * 73 + SPWriter.compactSize(script.count).count + script.count
                if input.scriptType == .p2shP2wsh { extraBase += 35 }
            case .p2tr:
                if value(map, [0x17]) != nil, map.contains(where: { $0.key.first == 0x15 }) == false {
                    // 64-byte signature, plus the sighash byte unless it's DEFAULT.
                    witness += 66 + (value(map, [0x03]).map { $0.first != 0 } == true ? 1 : 0)
                } else if let leaf = tapLeafScripts(map).first {
                    // multi_a: n keys, m signatures (65 bytes), an empty push for each missing one.
                    let n = pushes(leaf.script).filter { $0.count == 32 }.count
                    let ops = leaf.script.suffix(2)
                    let m = ops.last == 0x9C && (0x51...0x60).contains(ops.first ?? 0) ? Int(ops.first!) - 0x50 : n
                    witness += 1 + m * 66 + (n - m) + SPWriter.compactSize(leaf.script.count).count + leaf.script.count + 1 + leaf.controlBlock.count
                } else {
                    witness += 66
                }
            default: extraBase += 107
            }
        }
        return ((baseSize + extraBase) * 4 + witness + 3) / 4
    }

    // MARK: PSBT helpers

    struct Origin { let fingerprint: String; let path: [UInt32] }

    private static func value(_ map: [SPPsbt.Entry], _ key: [UInt8]) -> [UInt8]? {
        map.first { $0.key == key }?.value
    }

    /// fingerprint (4) || path (4 bytes LE each)
    static func keyOrigin(_ value: [UInt8]) -> Origin? {
        guard value.count >= 4, (value.count - 4) % 4 == 0 else { return nil }
        let path = stride(from: 4, to: value.count, by: 4).map {
            UInt32(value[$0]) | UInt32(value[$0 + 1]) << 8 | UInt32(value[$0 + 2]) << 16 | UInt32(value[$0 + 3]) << 24
        }
        return Origin(fingerprint: SPHexFN.encode(value[0..<4]), path: path)
    }

    /// compactSize n || n × leaf hash || key origin
    static func tapKeyOrigin(_ value: [UInt8]) -> (leafHashes: [[UInt8]], origin: Origin)? {
        var reader = SPReader(value)
        guard let count = try? reader.compactSize() else { return nil }
        var hashes: [[UInt8]] = []
        for _ in 0..<count {
            guard let hash = try? reader.bytes(32) else { return nil }
            hashes.append(hash)
        }
        guard let origin = keyOrigin(Array(value.suffix(reader.remaining))) else { return nil }
        return (hashes, origin)
    }

    /// Every key origin in an input or output map (BIP32 and taproot derivations).
    private static func origins(in map: [SPPsbt.Entry]) -> [Origin] {
        map.compactMap { entry -> Origin? in
            switch (entry.key.first, entry.key.count) {
            case (0x06, 34), (0x02, 34): return keyOrigin(entry.value)
            case (0x16, 33), (0x07, 33): return tapKeyOrigin(entry.value)?.origin
            default: return nil
            }
        }
    }

    private static func readOutput(_ bytes: [UInt8]) throws -> SPTx.Output {
        var reader = SPReader(bytes)
        return try SPTx.readOutput(&reader)
    }

    static func amount(_ output: SPTx.Output) -> UInt64 {
        output.amount.enumerated().reduce(UInt64(0)) { $0 | UInt64($1.element) << (8 * UInt64($1.offset)) }
    }

    private static func address(_ spk: [UInt8], _ network: BitcoinDevKit.Network) -> String? {
        try? Address.fromScript(script: Script(rawOutputScript: Data(spk)), network: network).description
    }

    /// txid (internal byte order) of a serialized transaction, segwit or not.
    static func txidInternal(_ bytes: [UInt8]) throws -> [UInt8] {
        var reader = SPReader(bytes)
        _ = try reader.bytes(4)
        var segwit = false
        if reader.peek(2) == [0x00, 0x01] { _ = try reader.bytes(2); segwit = true }
        let start = segwit ? 6 : 4
        let inCount = try reader.compactSize()
        for _ in 0..<inCount {
            _ = try reader.bytes(36)
            _ = try reader.bytes(try reader.compactSize())
            _ = try reader.bytes(4)
        }
        let outCount = try reader.compactSize()
        for _ in 0..<outCount {
            _ = try reader.bytes(8)
            _ = try reader.bytes(try reader.compactSize())
        }
        let end = bytes.count - reader.remaining
        let stripped = Array(bytes[0..<4]) + Array(bytes[start..<end]) + Array(bytes.suffix(4))
        return [UInt8](SHA256.hash(data: [UInt8](SHA256.hash(data: stripped))))
    }
}
