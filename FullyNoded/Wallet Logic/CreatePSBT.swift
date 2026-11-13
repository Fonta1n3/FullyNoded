////
////  CreatePSBT.swift
////  BitSense
////
////  Copyright © 2019 Fontaine. All rights reserved.
////
//
import Foundation


class CreatePSBT {

    /// - changeAddress: optional explicit change destination (e.g. when the active wallet
    ///   is a watch-only wallet that can't generate change addresses).
    /// - subtractFeeFromOutputs: output indices that pay the fee (a sweep: the output carries
    ///   the inputs' total and the fee comes out of it, so there's no change).
    class func create(inputs: [[String: Any]],
                      outputs: [[String: Any]],
                      changeAddress: String? = nil,
                      subtractFeeFromOutputs: [Int]? = nil,
                      completion: @escaping ((psbt: String?, rawTx: String?, errorMessage: String?)) -> Void) {

        func buildParams(inputs: [[String: Any]], locktime: UInt32?) -> [String: Any] {
            var paramDict: [String: Any] = [:]
            paramDict["outputs"] = outputs
            paramDict["inputs"] = inputs
            paramDict["bip32derivs"] = true
            if let locktime, locktime > 0 {
                paramDict["locktime"] = locktime
            }

            var options: [String: Any] = [:]
            options["includeWatching"] = true
            options["replaceable"] = true
            if let changeAddress, !changeAddress.isEmpty {
                options["changeAddress"] = changeAddress
            }
            if let subtractFeeFromOutputs, !subtractFeeFromOutputs.isEmpty {
                options["subtractFeeFromOutputs"] = subtractFeeFromOutputs
            }
            if let feeRate = UserDefaults.standard.object(forKey: "feeRate") as? Int {
                options["fee_rate"] = feeRate
            } else if let feeTarget = UserDefaults.standard.object(forKey: "feeTarget") as? Int {
                options["conf_target"] = feeTarget
            }
            paramDict["options"] = options
            return paramDict
        }

        func requestPSBT(params: [String: Any], completion: @escaping (String?, String?) -> Void) {
            let param = Wallet_Create_Funded_Psbt(params)
            MakeRPCCall.sharedInstance.executeRPCCommand(method: .walletcreatefundedpsbt(param: param)) { response, errorMessage in
                guard let result = response as? NSDictionary, let psbt = result["psbt"] as? String else {
                    var desc = errorMessage ?? "unknown error"
                    if desc.contains("Unexpected key fee_rate") {
                        desc = "In order to set the fee rate manually you must update to Bitcoin Core 0.21."
                    }
                    completion(nil, desc)
                    return
                }
                completion(psbt, nil)
            }
        }

        func cltv(from hex: String) -> UInt32? {
            WalletLogic.shared.extractCLTV(fromWitnessScript: hex)
        }

        func requiredLocktime(from bdkPsbt: WalletLogic.BDKPsbt) -> UInt32 {
            var lock: UInt32 = 0

            for input in bdkPsbt.input() {
                if let ws = input.witnessScript {
                    if let v = cltv(from: ws.toBytes().hex) {
                        lock = max(lock, v)
                    }
                }
                
                if let rs = input.redeemScript {
                    if let v = cltv(from: rs.toBytes().hex) {
                        lock = max(lock, v)
                    }
                }
                
                let leaves = input.tapScripts
                for leaf in leaves {
                    let scriptHex: String
                    let s = leaf.value.script
                    scriptHex = s.toBytes().hex
                    
                    if let v = cltv(from: scriptHex) {
                        lock = max(lock, v)
                    }
                }
            }

            return lock
        }

        func txLocktime(_ tx: Any) -> UInt32 {
            if let n = (tx as AnyObject).value(forKey: "lockTime") as? UInt32 {
                return n
            }
            return 0
        }

        requestPSBT(params: buildParams(inputs: inputs, locktime: nil)) { psbt, error in
            guard let psbt else {
                completion((nil, nil, error))
                return
            }

            guard let bdkPsbt = try? WalletLogic.BDKPsbt(psbtBase64: psbt) else {
                completion((psbt, nil, nil))
                return
            }

            let needed = requiredLocktime(from: bdkPsbt)

            var currentLock: UInt32 = 0
            if let tx = try? bdkPsbt.extractTx() {
                currentLock = UInt32(truncatingIfNeeded: tx.lockTime())
            }

            if needed == 0 || currentLock >= needed {
                completion((psbt, nil, nil))
                return
            }

            // Core picked the inputs itself and one of them may still be timelocked (it counts
            // timelocked coins as spendable). Consensus compares a time-based lock with the chain's
            // median time past (and a height-based one with the next block's height), not with this
            // device's clock, so that's what the lock is checked against. If it hasn't passed, the
            // transaction can't be broadcast yet, so don't hand it over without saying so.
            // (When the user picked the inputs themselves, a future locktime is deliberate.)
            func proceed() {
                var pinnedInputs: [[String: Any]] = []
                if let tx = try? bdkPsbt.extractTx() {
                    for prev in tx.input() {
                        pinnedInputs.append([
                            "txid": prev.previousOutput.txid.description,
                            "vout": prev.previousOutput.vout,
                            "sequence": 1
                        ])
                    }
                } else {
                    pinnedInputs = inputs.map { input in
                        var copy = input
                        copy["sequence"] = 1
                        return copy
                    }
                }

                requestPSBT(params: buildParams(inputs: pinnedInputs, locktime: needed)) { rebuilt, rebuildError in
                    if let rebuilt {
                        completion((rebuilt, nil, rebuildError))
                    } else {
                        completion((nil, nil, rebuildError))
                    }
                }
            }

            guard inputs.isEmpty else { proceed(); return }

            MakeRPCCall.sharedInstance.executeRPCCommand(method: .getblockchaininfo) { response, _ in
                guard let info = response as? [String: Any],
                      let height = info["blocks"] as? Int,
                      let medianTime = info["mediantime"] as? Int else {
                    proceed()   // can't tell: let the node judge at broadcast
                    return
                }
                let lock = Int(needed)
                let isOpen = lock >= 500_000_000 ? lock < medianTime : lock <= height
                if isOpen {
                    proceed()
                } else {
                    let when = lock >= 500_000_000
                        ? Date(timeIntervalSince1970: TimeInterval(lock)).formatted(date: .abbreviated, time: .shortened)
                        : "block \(lock)"
                    completion((nil, nil, "This amount would need coins that are timelocked until \(when), so the transaction could not be broadcast before then. Send a smaller amount, or choose specific UTXO's to spend."))
                }
            }
        }
    }
}
