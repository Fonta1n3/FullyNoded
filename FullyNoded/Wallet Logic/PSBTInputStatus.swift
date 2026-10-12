//
//  PSBTInputStatus.swift
//  FullyNoded
//
//  Signature status of a decoded PSBT input (decodepsbt JSON): signatures present,
//  the m in m-of-n parsed from its scripts, and how many are still needed.
//

import Foundation
import CryptoKit

enum PSBTInputStatus {

    /// Signature state of one input.
    struct Status {
        let present: Int
        /// Signatures the input needs. A floor (not a fact) when `requiredKnown` is false.
        let required: Int
        let needed: Int
        /// False when nothing in the PSBT says how many signatures are needed (no script, and not a
        /// recognisable single-sig output), so `required` is only a guess of at least 1.
        let requiredKnown: Bool
        /// Signers (master fingerprint, else the key itself) that haven't signed yet but could.
        let unsignedSigners: [String]
    }
    
    static func sigsNeeded(from inputDict: [String: Any]) -> (present: Int, required: Int, needed: Int) {
        let status = status(from: inputDict)
        return (status.present, status.required, status.needed)
    }
    
    static func status(from inputDict: [String: Any]) -> Status {
        // Finalizing clears the scripts and partial signatures, so a finalized input is simply done.
        if let finalWitness = inputDict["final_scriptwitness"] as? [Any], !finalWitness.isEmpty {
            return Status(present: 1, required: 1, needed: 0, requiredKnown: true, unsignedSigners: [])
        }
        if let finalSig = inputDict["final_scriptSig"] as? [String: Any],
           let hex = finalSig["hex"] as? String, !hex.isEmpty {
            return Status(present: 1, required: 1, needed: 0, requiredKnown: true, unsignedSigners: [])
        }
        
        let signers = signerLookup(inputDict)
        func signerId(_ key: String) -> String { signers[key.lowercased()] ?? "key:" + key.lowercased() }
        
        // A taproot input is spent through ONE leaf, so judge each leaf on its own and report the
        // one needing the fewest more signatures. (Summing signatures and taking the largest m
        // across leaves misreports scripts with several leaves, e.g. a multisig plus a recovery key.)
        if let taproot = taprootLeafStatus(from: inputDict, signerId: signerId) { return taproot }
        
        let partial = (inputDict["partial_signatures"] as? [String: Any]) ?? (inputDict["partial_sigs"] as? [String: Any]) ?? [:]
        let present = partial.count
        let signedKeys = Set(partial.keys.map { $0.lowercased() })
        
        // m-of-n (or timelocked / multi-key) scripts say how many signatures they need.
        for scriptHex in [scriptHex(inputDict["witness_script"]), scriptHex(inputDict["redeem_script"])] {
            guard let hex = scriptHex, let data = Data(hexString: hex) else { continue }
            let bytes = [UInt8](data)
            let required = extractThreshold(from: bytes)
            guard required > 0 else { continue }
            
            let unsigned = scriptKeys(from: bytes).filter { !signedKeys.contains($0) }.map(signerId)
            return Status(present: present, required: required, needed: max(0, required - present),
                          requiredKnown: true, unsignedSigners: unsigned)
        }
        
        // A recognisable single-key output needs exactly one signature.
        if isSingleSig(inputDict) {
            let unsigned = present > 0 ? [] : Array(Set(signers.values))
            return Status(present: present, required: 1, needed: present > 0 ? 0 : 1,
                          requiredKnown: true, unsignedSigners: unsigned)
        }
        
        // Nothing says how many are needed: don't pretend to know.
        return Status(present: present, required: max(1, present), needed: present > 0 ? 0 : 1,
                      requiredKnown: false, unsignedSigners: Array(Set(signers.values)))
    }
    
    /// The fewest MORE signers that would complete every input. Inputs can be signed by different
    /// cosigners, so the largest per-input need (the old answer) understates it: if input 1 still
    /// needs A and input 2 still needs B, that is two signers, not one. `isLowerBound` when some
    /// input doesn't say how many signatures it needs.
    static func additionalSignersNeeded(_ statuses: [Status]) -> (count: Int, isLowerBound: Bool) {
        let isLowerBound = statuses.contains { !$0.requiredKnown }
        let pending = statuses.filter { $0.needed > 0 }
        guard !pending.isEmpty else { return (0, isLowerBound) }
        
        let fallback = pending.map { $0.needed }.max() ?? 0
        let ids = Array(Set(pending.flatMap { $0.unsignedSigners }))
        // Can't say who could still sign (or too many to search): fall back to the largest per-input need.
        guard pending.allSatisfy({ $0.unsignedSigners.count >= $0.needed }), ids.count <= 16 else {
            return (fallback, isLowerBound)
        }
        
        let index = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        let requirements: [(need: Int, bits: [Int])] = pending.map { ($0.needed, $0.unsignedSigners.compactMap { index[$0] }) }
        
        var best = Int.max
        for subset in 1..<(1 << ids.count) {
            let size = subset.nonzeroBitCount
            if size >= best { continue }
            if requirements.allSatisfy({ requirement in
                requirement.bits.filter { subset & (1 << $0) != 0 }.count >= requirement.need
            }) {
                best = size
            }
        }
        return (best == Int.max ? fallback : best, isLowerBound)
    }
    
    // MARK: - Helpers
    
    /// public key (lowercase hex) -> master fingerprint, from the PSBT's derivation records.
    private static func signerLookup(_ inputDict: [String: Any]) -> [String: String] {
        var lookup: [String: String] = [:]
        for field in ["bip32_derivs", "taproot_bip32_derivs"] {
            for record in inputDict[field] as? [[String: Any]] ?? [] {
                if let pubkey = record["pubkey"] as? String, let fingerprint = record["master_fingerprint"] as? String {
                    lookup[pubkey.lowercased()] = fingerprint.lowercased()
                }
            }
        }
        return lookup
    }
    
    private static func scriptHex(_ field: Any?) -> String? {
        (field as? [String: Any])?["hex"] as? String
    }
    
    /// P2WPKH, P2PKH, P2SH-P2WPKH, or a taproot output with no script tree: one signature.
    private static func isSingleSig(_ inputDict: [String: Any]) -> Bool {
        let outputType = ((inputDict["witness_utxo"] as? [String: Any])?["scriptPubKey"] as? [String: Any])?["type"] as? String
        if outputType == "witness_v0_keyhash" || outputType == "pubkeyhash" { return true }
        if outputType == "witness_v1_taproot", inputDict["taproot_scripts"] == nil, inputDict["taproot_merkle_root"] == nil { return true }
        if let redeem = scriptHex(inputDict["redeem_script"]),
           redeem.range(of: "^0014[0-9a-fA-F]{40}$", options: .regularExpression) != nil { return true }
        return false
    }
    
    // MARK: - Taproot leaves
    
    /// Best leaf of a taproot input that has script leaves: signatures present on that leaf (matched
    /// by leaf hash), the signatures it needs, and how many are missing. A key-path signature
    /// completes the input by itself. nil when the input has no parseable leaf (key-path only, or
    /// not taproot), so the caller falls back to the generic logic.
    private static func taprootLeafStatus(from inputDict: [String: Any], signerId: (String) -> String) -> Status? {
        if inputDict["taproot_key_path_sig"] != nil {
            return Status(present: 1, required: 1, needed: 0, requiredKnown: true, unsignedSigners: [])
        }
        
        guard let leaves = inputDict["taproot_scripts"] as? [[String: Any]], !leaves.isEmpty else { return nil }
        let sigs = inputDict["taproot_script_path_sigs"] as? [[String: Any]] ?? []
        
        func evaluate(byLeafHash: Bool) -> Status? {
            var best: Status?
            for leaf in leaves {
                guard let scriptHex = leaf["script"] as? String, let data = Data(hexString: scriptHex) else { continue }
                let bytes = [UInt8](data)
                let required = extractThreshold(from: bytes)
                guard required > 0 else { continue }
                
                let hash = leafHash(scriptHex: scriptHex, version: leaf["leaf_ver"] as? Int ?? 0xc0)
                let script = scriptHex.lowercased()
                let leafSigs = sigs.filter { sig in
                    if byLeafHash {
                        guard let hash = hash else { return false }
                        return (sig["leaf_hash"] as? String)?.lowercased() == hash
                    }
                    // Fallback if the leaf hash can't be computed: the signing key appears in the leaf.
                    guard let pubkey = (sig["pubkey"] as? String)?.lowercased(), !pubkey.isEmpty else { return false }
                    return script.contains(pubkey)
                }
                let signedKeys = Set(leafSigs.compactMap { ($0["pubkey"] as? String)?.lowercased() })
                let unsigned = scriptKeys(from: bytes).filter { !signedKeys.contains($0) }.map(signerId)
                
                let candidate = Status(present: leafSigs.count, required: required, needed: max(0, required - leafSigs.count),
                                       requiredKnown: true, unsignedSigners: unsigned)
                if best == nil || candidate.needed < best!.needed { best = candidate }
            }
            return best
        }
        
        let byHash = evaluate(byLeafHash: true)
        // Signatures exist but none matched a leaf hash: the hash couldn't be trusted, match on keys.
        if !sigs.isEmpty, (byHash?.present ?? 0) == 0 { return evaluate(byLeafHash: false) ?? byHash }
        return byHash
    }
    
    /// BIP341 tapleaf hash: tagged_hash("TapLeaf", leaf_version || compact_size(len) || script).
    private static func leafHash(scriptHex: String, version: Int) -> String? {
        guard let script = Data(hexString: scriptHex) else { return nil }
        
        var size = Data()
        switch script.count {
        case 0..<0xfd: size.append(UInt8(script.count))
        case 0xfd...0xffff: size.append(contentsOf: [0xfd, UInt8(script.count & 0xff), UInt8(script.count >> 8)])
        default:
            size.append(contentsOf: [0xfe] + (0..<4).map { UInt8((script.count >> (8 * $0)) & 0xff) })
        }
        
        var payload = Data([UInt8(truncatingIfNeeded: version)])
        payload.append(size)
        payload.append(script)
        
        let tag = Data(SHA256.hash(data: Data("TapLeaf".utf8)))
        let digest = SHA256.hash(data: tag + tag + payload)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Script thresholds
    
    static func extractThreshold(fromHex hex: String) -> Int {
        guard let data = Data(hexString: hex) else { return 0 }
        return extractThreshold(from: [UInt8](data))
    }
    
    private enum Element {
        case number(Int)
        case data([UInt8])
        case op(UInt8)
    }
    
    /// Public keys (x-only 32, compressed 33, uncompressed 65 bytes) pushed by a script, as lowercase hex.
    static func scriptKeys(from script: [UInt8]) -> [String] {
        tokenize(script).compactMap { item in
            guard case .data(let bytes) = item, [32, 33, 65].contains(bytes.count) else { return nil }
            return bytes.map { String(format: "%02x", $0) }.joined()
        }
    }
    
    /// Splits a script into numbers, data pushes and opcodes. Empty if the script is malformed.
    private static func tokenize(_ script: [UInt8]) -> [Element] {
        var items: [Element] = []
        var i = 0
        
        while i < script.count {
            let op = script[i]
            switch op {
            case 0x00:
                items.append(.number(0)); i += 1
            case 0x01...0x4b:
                let length = Int(op)
                guard i + 1 + length <= script.count else { return [] }
                let pushed = Array(script[(i + 1)..<(i + 1 + length)])
                // Short pushes are script numbers (a threshold above 16, a locktime...); long ones are keys.
                items.append(length <= 4 ? .number(scriptNumber(pushed[...])) : .data(pushed))
                i += 1 + length
            case 0x4c, 0x4d, 0x4e:
                let width = op == 0x4c ? 1 : (op == 0x4d ? 2 : 4)
                guard i + width < script.count else { return [] }
                var length = 0
                for b in 0..<width { length |= Int(script[i + 1 + b]) << (8 * b) }
                guard i + 1 + width + length <= script.count else { return [] }
                items.append(.data(Array(script[(i + 1 + width)..<(i + 1 + width + length)])))
                i += 1 + width + length
            case 0x4f:
                items.append(.number(-1)); i += 1
            case 0x51...0x60:
                items.append(.number(Int(op) - 0x50)); i += 1
            default:
                items.append(.op(op)); i += 1
            }
        }
        return items
    }
    
    /// Signatures a script needs, from its opcodes. Handles:
    ///  - classic `m <keys> n CHECKMULTISIG(VERIFY)`: m is read from where it sits relative to n (not
    ///    "the first number"), so a timelock pushed before the multisig can't be mistaken for it;
    ///  - taproot `multi_a`: `<k1> CHECKSIG <k2> CHECKSIGADD ... <m> NUMEQUAL(VERIFY)`;
    ///  - plain CHECKSIG(VERIFY), one signature each;
    ///  - thresholds above 16, which are pushed as data rather than OP_n.
    /// Groups in a linear script all have to be satisfied, so they add up. With IF/ELSE branches it
    /// is the cheapest group (a lower bound: choosing the branch is the signer's business).
    /// 0 when the script has no signature check at all.
    static func extractThreshold(from script: [UInt8]) -> Int {
        let items = tokenize(script)
        guard !items.isEmpty else { return 0 }
        
        var groups: [Int] = []
        var pendingSigOps = 0   // CHECKSIG / CHECKSIGADD not yet claimed by a multi_a threshold
        var branching = false
        
        for (index, item) in items.enumerated() {
            guard case .op(let op) = item else { continue }
            switch op {
            case 0x63, 0x64, 0x67: // IF, NOTIF, ELSE
                branching = true
            case 0xac, 0xad, 0xba: // CHECKSIG, CHECKSIGVERIFY, CHECKSIGADD
                pendingSigOps += 1
            case 0x9c, 0x9d: // NUMEQUAL(VERIFY) closes a multi_a: the number just before it is m
                if index > 0, case .number(let m) = items[index - 1], m > 0, pendingSigOps > 0 {
                    groups.append(m)
                    pendingSigOps = 0
                }
            case 0xae, 0xaf: // CHECKMULTISIG(VERIFY): n is just before, m sits before the n keys
                guard index > 0, case .number(let n) = items[index - 1], n >= 1,
                      index - 2 - n >= 0, case .number(let m) = items[index - 2 - n], m >= 1 else { return 0 }
                groups.append(m)
            default:
                break
            }
        }
        groups.append(contentsOf: Array(repeating: 1, count: pendingSigOps))
        
        guard !groups.isEmpty else { return 0 }
        return branching ? (groups.min() ?? 0) : groups.reduce(0, +)
    }
    
    /// Minimally-encoded little-endian script number (sign in the top bit of the last byte).
    private static func scriptNumber(_ bytes: ArraySlice<UInt8>) -> Int {
        guard let last = bytes.last else { return 0 }
        var value = 0
        for (shift, byte) in bytes.enumerated() { value |= Int(byte) << (8 * shift) }
        if last & 0x80 != 0 {
            value &= ~(0x80 << (8 * (bytes.count - 1)))
            return -value
        }
        return value
    }
}
