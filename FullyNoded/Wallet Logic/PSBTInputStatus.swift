//
//  PSBTInputStatus.swift
//  FullyNoded
//
//  Signature status of a decoded PSBT input (decodepsbt JSON): signatures present,
//  the m in m-of-n parsed from its scripts, and how many are still needed.
//

import Foundation

enum PSBTInputStatus {

    static func sigsNeeded(from inputDict: [String: Any]) -> (present: Int, required: Int, needed: Int) {
        var present = 0
        var required = 0
        
        // ---------- Present signatures ----------
        if let sigs = inputDict["taproot_script_path_sigs"] as? [[String: Any]] {
            present = sigs.count
        } else if inputDict["taproot_key_path_sig"] != nil {
            present = 1
        } else if let partial = inputDict["partial_sigs"] as? [String: Any] {
            present = partial.count
        } else if let partial = inputDict["partial_signatures"] as? [String: Any] {
            present = partial.count
        }
        
        if let finalWitness = inputDict["final_scriptwitness"] as? [Any], !finalWitness.isEmpty {
            present = max(present, 1)
        }
        if let finalSig = inputDict["final_scriptSig"] as? [String: Any],
           let hex = finalSig["hex"] as? String,
           !hex.isEmpty {
            present = max(present, 1)
        }
        
        // ---------- Required threshold ----------
        
        // Prefer every taproot leaf and take the highest m we can parse.
        if let scripts = inputDict["taproot_scripts"] as? [[String: Any]] {
            for scriptDict in scripts {
                if let scriptHex = scriptDict["script"] as? String {
                    required = max(required, extractThreshold(fromHex: scriptHex))
                }
            }
        }
        
        if required == 0, let witnessScript = inputDict["witness_script"] as? [String: Any],
           let hex = witnessScript["hex"] as? String {
            required = extractThreshold(fromHex: hex)
        }
        
        if required == 0, let redeemScript = inputDict["redeem_script"] as? [String: Any],
           let hex = redeemScript["hex"] as? String {
            required = extractThreshold(fromHex: hex)
        }
        
        // Single-sig fallback only when no m-of-n script was found.
        if required == 0 {
            let hasPartial =
                ((inputDict["partial_sigs"] as? [String: Any])?.isEmpty == false) ||
                ((inputDict["partial_signatures"] as? [String: Any])?.isEmpty == false)
            
            if inputDict["taproot_internal_key"] != nil ||
                inputDict["taproot_key_path_sig"] != nil ||
                inputDict["witness_script"] != nil ||
                inputDict["redeem_script"] != nil ||
                inputDict["bip32_derivs"] != nil ||
                inputDict["witness_utxo"] != nil ||
                inputDict["non_witness_utxo"] != nil ||
                hasPartial {
                required = 1
            }
        }
        
        if present > 0 && required == 0 {
            required = present
        }
        
        let needed = max(0, required - present)
        return (present, required, needed)
    }

    /// Classic multisig, CHECKSIG / CHECKSIGVERIFY, and Taproot multi_a (CHECKSIGADD).
    static func extractThreshold(fromHex hex: String) -> Int {
        guard let script = Data(hexString: hex) else { return 0 }
        
        var i = 0
        var numbers: [Int] = []
        var sawChecksig = false
        var sawChecksigAdd = false
        
        func skipPush(_ length: Int) {
            i += length
        }
        
        while i < script.count {
            let op = script[i]
            
            if (1...75).contains(op) {
                i += 1 + Int(op)
                continue
            }
            
            if op == 0x4c { // OP_PUSHDATA1
                guard i + 1 < script.count else { return 0 }
                let len = Int(script[i + 1])
                i += 2
                skipPush(len)
                continue
            }
            if op == 0x4d { // OP_PUSHDATA2
                guard i + 2 < script.count else { return 0 }
                let len = Int(script[i + 1]) | (Int(script[i + 2]) << 8)
                i += 3
                skipPush(len)
                continue
            }
            if op == 0x4e { // OP_PUSHDATA4
                guard i + 4 < script.count else { return 0 }
                let len = Int(script[i + 1])
                    | (Int(script[i + 2]) << 8)
                    | (Int(script[i + 3]) << 16)
                    | (Int(script[i + 4]) << 24)
                i += 5
                skipPush(len)
                continue
            }
            
            // OP_0
            if op == 0x00 {
                numbers.append(0)
                i += 1
                continue
            }
            
            // OP_1 ... OP_16
            if (0x51...0x60).contains(op) {
                numbers.append(Int(op) - 0x50)
                i += 1
                continue
            }
            
            // CHECKMULTISIG / CHECKMULTISIGVERIFY → classic m-of-n, m is the first small-int
            if op == 0xae || op == 0xaf {
                return numbers.first ?? 0
            }
            
            // CHECKSIGADD (Taproot / BIP342 multi_a)
            if op == 0xba {
                sawChecksigAdd = true
                i += 1
                continue
            }
            
            // CHECKSIG / CHECKSIGVERIFY
            if op == 0xac || op == 0xad {
                sawChecksig = true
                i += 1
                continue
            }
            
            // NUMEQUAL / NUMEQUALVERIFY → threshold is the last small-int (e.g. OP_2 OP_NUMEQUAL)
            if op == 0x9c || op == 0x9d {
                if sawChecksigAdd || sawChecksig {
                    return numbers.last ?? 0
                }
                i += 1
                continue
            }
            
            // CLTV, CSV, DROP, etc.
            i += 1
        }
        
        if sawChecksigAdd {
            return numbers.last ?? 0
        }
        if sawChecksig {
            return 1
        }
        return 0
    }
}
