//
//  BlindPsbt.swift
//  FullyNoded
//
//  Created by Peter Denton on 7/25/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation
import LibWally

class BlindPsbt {
    
    // Used when creating a transaction via the send view when blind psbts is on.
    // Takes the amount of the user specified output, and creates 3 utxos with similar denominations and script types.
    static func getInputs(amountBtc: Double,
                          recipient: String?,
                          completion: @escaping (((psbt: String?, error: String?)) -> Void)) {
        
        var inputArray = [String]()
        
        guard amountBtc > 0.0 else {
            completion((nil, "No amount specified."))
            return
        }
        
        func getNow(recipient: String) {
            Reducer.makeCommand(command: .listunspent, param: "") { (response, errorMessage) in
                guard let utxos = response as? [[String:Any]], utxos.count > 0 else {
                    completion((nil, "No inputs to spend."))
                    return
                }
                
                var totalInputAmount = 0.0
                var type:ScriptPubKey.ScriptType!
                
                func finish() {
                    if inputArray.count == 0 {
                        completion((nil,
                                    "You do not have any similarly denominated utxos, or matching script types. Use the divide button to split your utxos into designated amounts."))
                    } else if inputArray.count == 3 {
                        BlindPsbt.getOutputs(inputArray.processedInputs, amountBtc, recipient, type, totalInputAmount, completion: completion)
                    }
                }
                
                for (i, utxo) in utxos.enumerated() {
                    let utxoStr = UtxosStruct(dictionary: utxo)
                    
                    if (utxoStr.solvable ?? false == true) {
                        guard let recipientAddress = try? Address(string: recipient) else {
                            completion((nil, "Recipient address invalid."))
                            return
                        }
                        
                        guard let inputAddress = try? Address(string: utxoStr.address ?? "") else {
                            completion((nil, "Input address invalid."))
                            return
                        }
                        
                        if recipientAddress.scriptPubKey.type == inputAddress.scriptPubKey.type {
                            type = recipientAddress.scriptPubKey.type
                            
                            if utxoStr.amount! == amountBtc {
                                if inputArray.count < 3 {
                                    totalInputAmount += utxoStr.amount!
                                    inputArray.append(utxoStr.input)
                                }
                            }
                        }
                    }
                    
                    if i + 1 == utxos.count {
                        finish()
                    }
                }
            }
        }
        
        if let recipient = recipient {
            getNow(recipient: recipient)
        } else {
            activeWallet { wallet in
                guard let wallet = wallet else {
                    completion((nil, "Blinded psbt's only work with Fully Noded wallets."))
                    return
                }
                
                let startIndex = Int(wallet.index + 4)
                let descriptor = wallet.changeDescriptor
                
                Reducer.makeCommand(command: .deriveaddresses, param: "\"\(descriptor)\", [\(startIndex),\(startIndex)]") { (response, errorMessage) in
                    guard let addresses = response as? [String] else {
                        completion((nil, "addresses not returned: \(errorMessage ?? "unknown error.")"))
                        return
                    }
                    
                    getNow(recipient: addresses[0])
                }
            }
        }
    }
    
    // Used when creating a transaction via the send view when blind psbts is on.
    // Takes the user specified output amount and adds two similiarly denominated outputs.
    static func getOutputs(_ inputs: String,
                           _ amount: Double,
                           _ recipient: String,
                           _ type: ScriptPubKey.ScriptType,
                           _ totalInputAmount: Double,
                           completion: @escaping (((psbt: String?, error: String?)) -> Void)) {
                
        activeWallet { wallet in
            guard let wallet = wallet else {
                completion((nil, "Blind psbt's only work with Fully Noded wallets for now."))
                return
            }
            
            let startIndex = Int(wallet.index + 2)
            let stopIndex = (startIndex + 1)
            let descriptor = wallet.changeDescriptor
            
            Reducer.makeCommand(command: .deriveaddresses, param: "\"\(descriptor)\", [\(startIndex),\(stopIndex)]") { (response, errorMessage) in
                guard let addresses = response as? [String] else {
                    completion((nil, "addresses not returned: \(errorMessage ?? "unknown error.")"))
                    return
                }
                
                var outputs = [[String:Any]]()
                outputs.append([recipient:amount])
                            
                for (i, addr) in addresses.enumerated() {
                    if let scriptType = try? Address(string: addr).scriptPubKey.type, scriptType == type {
                        let output:[String:Any] = [addr:amount]
                        outputs.append(output)
                    }
                    
                    if i + 1 == addresses.count {
                        if outputs.count == 3 {
                            BlindPsbt.create(inputs: inputs, outputs: outputs.processedOutputs) { (psbt, errorMessage) in
                                guard let psbt = psbt else {
                                    completion((nil, "psbt not returned: \(errorMessage ?? "unknown error.")"))
                                    return
                                }
                                
                                completion((psbt, nil))
                            }
                        } else {
                            completion((nil, "The active wallet does not have a matching script type as the recipient address."))
                        }
                    }
                }
            }
        }
    }
        
    static func parseBlindPsbt(_ encryptedPsbt: Data, completion: @escaping (((joinedPsbt: String?, error: String?)) -> Void)) {
        //inputs are divisible by 3, identical output amounts, all either p2wpkh or wsh inputs/outputs
        
        guard let decryptedPsbtData = Crypto.decryptPsbt(encryptedPsbt) else {
            completion((nil, "Error decrypting the blinded psbt."))
            return
        }
        
        guard let receivedPsbt = try? PSBT(psbt: decryptedPsbtData.base64EncodedString(), network: .testnet) else { return }
            
        var amountArray = [Double]()

        for input in receivedPsbt.inputs {
            if let sats = input.amount {
                amountArray.append(Double(sats).satsToBtcDouble)
            }
        }

        let duplicates = amountArray.duplicates()

        if duplicates.count > 1 {
            // prompt to choose output amount
            completion((nil, "There are multiple output amounts, for now this feature only works with transactions containing identical output amounts."))
            return

        } else if duplicates.count == 1 {
            BlindPsbt.getInputs(amountBtc: duplicates[0], recipient: nil) { (psbt, error) in

                guard let ourPsbt = psbt else {
                    completion((nil, "There was an error creating a joined blinded psbt: \(error ?? "unknown error")"))
                    return
                }
                
                Reducer.makeCommand(command: .joinpsbts, param: "[\"\(ourPsbt)\", \"\(decryptedPsbtData.base64EncodedString())\"]") { (response, errorMessage) in
                    guard let response = response as? String else {
                        completion((nil, "There was an error joining the psbts: \(error ?? "unknown error")"))
                        return
                    }

                    completion((response, nil))
                }
            }
        }
    }
    
    class func create(inputs: String, outputs: String, completion: @escaping ((psbt: String?, errorMessage: String?)) -> Void) {
        var param = ""
        
        if let feeRate = UserDefaults.standard.object(forKey: "feeRate") as? Int {
            
            param = "\(inputs), ''{\(outputs)}'', 0, {\"includeWatching\": true, \"replaceable\": true, \"fee_rate\": \(feeRate), \"subtractFeeFromOutputs\": [0,1,2]}, true"
            
        } else if let feeTarget = UserDefaults.standard.object(forKey: "feeTarget") as? Int {
                        
            param = "\(inputs), ''{\(outputs)}'', 0, {\"includeWatching\": true, \"replaceable\": true, \"conf_target\": \(feeTarget), \"subtractFeeFromOutputs\": [0,1,2]}, true"
        }
                
        Reducer.makeCommand(command: .walletcreatefundedpsbt, param: param) { (response, errorMessage) in
            guard let result = response as? NSDictionary, let psbt = result["psbt"] as? String else {
                var desc = errorMessage ?? "unknown error"
                if desc.contains("Unexpected key fee_rate") {
                    desc = "In order to set the fee rate manually you must update to Bitcoin Core 0.21."
                }
                completion((nil, desc))
                return
            }
            
            completion((psbt, errorMessage))
        }
    }
}
