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
                          strict: Bool,
                          inputsToJoin:[String]?,
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
                        completion((nil, "Looks like you do not have any suitable utxos for this transaction type."))
                        
                    } else if inputArray.count > 0 {
                        
                        BlindPsbt.getOutputs(inputArray.processedInputs,
                                             amountBtc,
                                             recipient,
                                             type,
                                             totalInputAmount,
                                             strict,
                                             completion: completion)
                    }
                }
                
                activeWallet { wallet in
                    if let wallet = wallet {
                        if !wallet.receiveDescriptor.hasPrefix("combo") {
                            
                            for (i, utxo) in utxos.enumerated() {
                                let utxoStr = UtxosStruct(dictionary: utxo)
                                
                                var solvable = false
                                if let solvableCheck = utxoStr.solvable {
                                    solvable = solvableCheck
                                }
                                
                                if solvable {
                                    
                                    func append() {
                                        totalInputAmount += utxoStr.amount!
                                        inputArray.append(utxoStr.input)
                                                                                
                                        if i + 1 == utxos.count {
                                            finish()
                                        }
                                    }
                                    
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
                                        
                                        var totalInputsAllowed = 1
                                        
                                        var rule = true
                                        
                                        if strict {
                                            rule = amountBtc == utxoStr.amount!
                                        } else {
                                            totalInputsAllowed = 2
                                        }
                                        
                                        if inputArray.count < totalInputsAllowed {
                                            
                                            if rule {
                                                var inputExists = false
                                                
                                                if inputArray.count > 0 {
                                                    for (x, input) in inputArray.enumerated() {
                                                        if input.contains(utxoStr.txid) && strict {
                                                            inputExists = true
                                                        }
                                                        if input == utxoStr.input {
                                                            inputExists = true
                                                        }
                                                        
                                                        if x + 1 == inputArray.count {
                                                            checkExisitingInputs()
                                                        }
                                                    }
                                                } else {
                                                    checkExisitingInputs()
                                                }
                                                
                                                func checkExisitingInputs() {
                                                    if let inputsToJoin = inputsToJoin, inputsToJoin.count > 0 {
                                                        for (y, inputToJoin) in inputsToJoin.enumerated() {
                                                            if inputToJoin == utxoStr.input {
                                                                inputExists = true
                                                            } else if inputToJoin.contains(utxoStr.txid) && strict {
                                                                inputExists = true
                                                            }
                                                            
                                                            if y + 1 == inputsToJoin.count && inputExists == false {
                                                                append()
                                                            } else if i + 1 == utxos.count {
                                                                finish()
                                                            }
                                                        }
                                                    } else if inputExists == false  {
                                                        append()
                                                    } else if i + 1 == utxos.count {
                                                        finish()
                                                    }
                                                }
                                    
                                            } else {
                                                if i + 1 == utxos.count {
                                                    if inputArray.count < 1 {
                                                        completion((nil, "It seems you do not have enough segregated utxos to create this type of transaction. Fully Noded does not allow utxos that are already linked together to be used in joined transactions."))
                                                    } else {
                                                        finish()
                                                    }
                                                }
                                            }
                                        } else if i + 1 == utxos.count {
                                            finish()
                                        }
                                    } else {
                                        if i + 1 == utxos.count {
                                            finish()
                                        }
                                    }
                                } else {
                                    if i + 1 == utxos.count {
                                        finish()
                                    }
                                }
                            }
                        } else {
                            completion((nil, "Blind psbts do not currently work with combo descriptors."))
                        }
                    } else {
                        completion((nil, "Blind psbts only work with Fully Noded wallets for now."))
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
                    
                    CoreDataService.update(id: wallet.id, keyToUpdate: "index", newValue: Int64(startIndex + 1), entity: .wallets) { _ in }
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
                           _ strict: Bool,
                           completion: @escaping (((psbt: String?, error: String?)) -> Void)) {
                
        activeWallet { wallet in
            guard let wallet = wallet else {
                completion((nil, "Blind psbt's only work with Fully Noded wallets for now."))
                return
            }
            
            let startIndex = Int(wallet.index + 1)
            let stopIndex = (startIndex + 1) //create an extra one just in case we need change
            let descriptor = wallet.changeDescriptor
            var totalOutputAmount = 0.0
            
            Reducer.makeCommand(command: .deriveaddresses, param: "\"\(descriptor)\", [\(startIndex),\(stopIndex)]") { (response, errorMessage) in
                guard let addresses = response as? [String] else {
                    completion((nil, "addresses not returned: \(errorMessage ?? "unknown error.")"))
                    return
                }
                
                var outputs = [[String:Any]]()
                outputs.append([recipient:amount])
                totalOutputAmount += amount
                
                CoreDataService.update(id: wallet.id, keyToUpdate: "index", newValue: Int64(stopIndex + 2), entity: .wallets) { _ in }
                
                var totalAllowedOutputs = 1
                
                if !strict {
                    totalAllowedOutputs = 2
                }
                            
                for (i, addr) in addresses.enumerated() {
                    if let scriptType = try? Address(string: addr).scriptPubKey.type, scriptType == type {
                        if outputs.count < totalAllowedOutputs {
                            let output:[String:Any] = [addr:amount]
                            totalOutputAmount += amount
                            outputs.append(output)
                        }
                    }
                    
                    if i + 1 == addresses.count {
                        if outputs.count == totalAllowedOutputs {
                            
                            BlindPsbt.create(inputs: inputs,
                                             outputs: outputs.processedOutputs,
                                             changeAddress: addresses[1],
                                             outputCount: outputs.count,
                                             strict: strict) { (psbt, errorMessage) in
                                
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
        guard let decryptedPsbtData = Crypto.decryptPsbt(encryptedPsbt) else {
            completion((nil, "Error decrypting the blinded psbt."))
            return
        }
        
        let psbt = decryptedPsbtData.base64EncodedString()
        var amountArray = [Double]()
        var inputArray = [String]()
        
        Reducer.makeCommand(command: .decodepsbt, param: "\"\(psbt)\"") { (response, errorMessage) in
            guard let dict = response as? NSDictionary else {
                completion((nil, errorMessage))
                return
            }
            
            let chain = UserDefaults.standard.object(forKey: "chain") as? String ?? "main"
            var network:Network = .mainnet
            if chain != "main" {
                network = .testnet
            }
            
            guard let receivedPsbt = try? PSBT(psbt: psbt, network: network) else { return }
            
            if let txDict = dict["tx"] as? NSDictionary {
                if let inputs = txDict["vin"] as? [[String:Any]] {
                    for input in inputs {
                        if let txid = input["txid"] as? String, let vout = input["vout"] as? Int {
                            inputArray.append("{\"txid\":\"\(txid)\",\"vout\": \(vout),\"sequence\": 1}")
                        }
                    }
                }
            }
            
            for (i, input) in receivedPsbt.inputs.enumerated() {
                if let sats = input.amount {
                    amountArray.append(Double(sats).satsToBtcDouble)
                }
                
                if i + 1 == receivedPsbt.inputs.count {
                    let strict = receivedPsbt.inputs.count == receivedPsbt.outputs.count && amountArray.dropFirst().allSatisfy({ $0 == amountArray.first })
                    
                    BlindPsbt.getInputs(amountBtc: amountArray[Int.random(in: 0..<amountArray.count)],
                                        recipient: nil,
                                        strict: strict,
                                        inputsToJoin: inputArray) { (psbt, error) in
                        
                        guard let ourPsbt = psbt else {
                            completion((nil, "There was an error creating a joined blinded psbt: \(error ?? "unknown error")"))
                            return
                        }
                        
                        Reducer.makeCommand(command: .joinpsbts, param: "[\"\(ourPsbt)\", \"\(decryptedPsbtData.base64EncodedString())\"]") { (response, errorMessage) in
                            guard let response = response as? String else {
                                completion((nil, "There was an error joining the psbts: \(errorMessage ?? "unknown error")"))
                                return
                            }
                            
                            completion((response, nil))
                        }
                    }
                }
            }
        }
    }
    
    class func create(inputs: String,
                      outputs: String,
                      changeAddress: String,
                      outputCount: Int,
                      strict: Bool,
                      completion: @escaping ((psbt: String?, errorMessage: String?)) -> Void) {
        
        var param = ""
        
        let randomInt = Int.random(in: 0..<outputCount)
        
        if let feeRate = UserDefaults.standard.object(forKey: "feeRate") as? Int {
            
            if strict {
                param = "\(inputs), ''{\(outputs)}'', 0, {\"includeWatching\": true, \"replaceable\": true, \"fee_rate\": \(feeRate), \"subtractFeeFromOutputs\": [0]}"
            } else {
                param = "\(inputs), ''{\(outputs)}'', 0, {\"includeWatching\": true, \"replaceable\": true, \"fee_rate\": \(feeRate), \"subtractFeeFromOutputs\": [\(randomInt)], \"changeAddress\": \"\(changeAddress)\", \"changePosition\": \(randomInt), \"add_inputs\": true}"
            }            
            
        } else if let feeTarget = UserDefaults.standard.object(forKey: "feeTarget") as? Int {
            
            if strict {
                param = "\(inputs), ''{\(outputs)}'', 0, {\"includeWatching\": true, \"replaceable\": true, \"conf_target\": \(feeTarget), \"subtractFeeFromOutputs\": [0]}"
            } else {
                param = "\(inputs), ''{\(outputs)}'', 0, {\"includeWatching\": true, \"replaceable\": true, \"conf_target\": \(feeTarget), \"subtractFeeFromOutputs\": [\(randomInt)], \"changeAddress\": \"\(changeAddress)\", \"changePosition\": \(randomInt), \"add_inputs\": true}"
            }
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
