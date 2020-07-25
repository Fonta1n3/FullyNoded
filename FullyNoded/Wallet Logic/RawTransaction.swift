//
//  RawTransaction.swift
//  BitSense
//
//  Created by Peter on 20/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class RawTransaction {
    
    var amount = Double()
    var addressToPay = ""
    var signedRawTx = ""
    var unsignedRawTx = ""
    var errorBool = Bool()
    var errorDescription = ""
    var numberOfBlocks = Int()
    var outputs = ""
    
    func rounded(number: Double) -> Double {
        return Double(round(100000000*number)/100000000)
    }
    
    func createRawTransactionFromHotWallet(completion: @escaping () -> Void) {
        func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
            Reducer.makeCommand(command: method, param: param) { [unowned vc = self] (response, errorMessage) in
                if errorMessage == nil {
                    switch method {
                    case .signrawtransactionwithwallet:
                        if let dict = response as? NSDictionary {
                            vc.signedRawTx = dict["hex"] as! String
                            completion()
                        }
                        
                    case .fundrawtransaction:
                        if let result = response as? NSDictionary {
                            let unsignedRawTx = result["hex"] as! String
                            executeNodeCommand(method: .signrawtransactionwithwallet, param: "\"\(unsignedRawTx)\"")
                        }
                        
                    case .createrawtransaction:
                        if let unsignedRawTx = response as? String {
                            let param = "\"\(unsignedRawTx)\", { \"includeWatching\":false, \"subtractFeeFromOutputs\":[], \"replaceable\": true, \"conf_target\": \(vc.numberOfBlocks) }"
                            executeNodeCommand(method: .fundrawtransaction, param: param)
                        }
                        
                    default:
                        break
                    }
                } else {
                    vc.errorBool = true
                    vc.errorDescription = errorMessage!
                    completion()
                }
            }
        }
        let receiver = "\"\(self.addressToPay)\":\(self.amount)"
        let param = "''[]'', ''{\(receiver)}'', 0, true"
        executeNodeCommand(method: BTC_CLI_COMMAND.createrawtransaction, param: param)
    }
    
    func createRawTransactionFromColdWallet(completion: @escaping () -> Void) {
        func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
            Reducer.makeCommand(command: method, param: param) { [unowned vc = self] (response, errorMessage) in
                if errorMessage == nil {
                    switch method {
                    case .fundrawtransaction:
                        if let result = response as? NSDictionary {
                            vc.unsignedRawTx = result["hex"] as! String
                            completion()
                        }
                    case .createrawtransaction:
                        if let unsignedRawTx = response as? String {
                            let param = "\"\(unsignedRawTx)\", { \"includeWatching\":true, \"subtractFeeFromOutputs\":[], \"replaceable\": true, \"conf_target\": \(vc.numberOfBlocks) }"
                            executeNodeCommand(method: .fundrawtransaction, param: param)
                        }
                    default:
                        break
                    }
                } else {
                    vc.errorBool = true
                    vc.errorDescription = errorMessage!
                    completion()
                }
            }
        }
        let receiver = "\"\(self.addressToPay)\":\(self.amount)"
        let param = "''[]'', ''{\(receiver)}'', 0, true"
        executeNodeCommand(method: .createrawtransaction, param: param)
    }
    
    func createBatchRawTransactionFromHotWallet(completion: @escaping () -> Void) {
        func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
            Reducer.makeCommand(command: method, param: param) { [unowned vc = self] (response, errorMessage) in
                if errorMessage == nil {
                    switch method {
                    case .signrawtransactionwithwallet:
                        if let dict = response as? NSDictionary {
                            vc.signedRawTx = dict["hex"] as! String
                            completion()
                        }
                    case .fundrawtransaction:
                        if let result = response as? NSDictionary {
                            let unsignedRawTx = result["hex"] as! String
                            executeNodeCommand(method: .signrawtransactionwithwallet, param: "\"\(unsignedRawTx)\"")
                        }
                    case .createrawtransaction:
                        if let unsignedRawTx = response as? String {
                            let param = "\"\(unsignedRawTx)\", { \"includeWatching\":false, \"subtractFeeFromOutputs\":[], \"replaceable\": true, \"conf_target\": \(vc.numberOfBlocks) }"
                            executeNodeCommand(method: .fundrawtransaction, param: param)
                        }
                    default:
                        break
                    }
                } else {
                    vc.errorBool = true
                    vc.errorDescription = errorMessage!
                    completion()
                }
            }
        }
        let param = "''[]'', ''{\(self.outputs)}'', 0, true"
        executeNodeCommand(method: .createrawtransaction, param: param)
    }
    
    func createBatchRawTransactionFromColdWallet(completion: @escaping () -> Void) {
        func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
            Reducer.makeCommand(command: method, param: param) { [unowned vc = self] (response, errorMessage) in
                if errorMessage == nil {
                    switch method {
                    case .fundrawtransaction:
                        if let result = response as? NSDictionary {
                            vc.unsignedRawTx = result["hex"] as! String
                            completion()
                        }
                    case .createrawtransaction:
                        if let unsignedRawTx = response as? String {
                            let param = "\"\(unsignedRawTx)\", { \"includeWatching\":true, \"subtractFeeFromOutputs\":[], \"replaceable\": true, \"conf_target\": \(vc.numberOfBlocks) }"
                            executeNodeCommand(method: .fundrawtransaction, param: param)
                        }
                    default:
                        break
                    }
                } else {
                    vc.errorBool = true
                    vc.errorDescription = errorMessage!
                    completion()
                }
            }
        }
        let param = "''[]'', ''{\(self.outputs)}'', 0, true"
        executeNodeCommand(method: .createrawtransaction, param: param)
    }
    
    func sweepRawTx(completion: @escaping () -> Void) {
        Reducer.makeCommand(command: .listunspent, param: "0") { [unowned vc = self] (response, errorMessage) in
            if let resultArray = response as? NSArray {
                var inputArray = [Any]()
                var inputs = ""
                var amount = Double()
                var spendFromCold = Bool()
                for utxo in resultArray {
                    let utxoDict = utxo as! NSDictionary
                    let txid = utxoDict["txid"] as! String
                    let vout = "\(utxoDict["vout"] as! Int)"
                    let spendable = utxoDict["spendable"] as! Bool
                    if !spendable {
                        spendFromCold = true
                    }
                    amount += utxoDict["amount"] as! Double
                    let input = "{\"txid\":\"\(txid)\",\"vout\": \(vout),\"sequence\": 1}"
                    inputArray.append(input)
                }
                inputs = inputArray.description
                inputs = inputs.replacingOccurrences(of: "[\"", with: "[")
                inputs = inputs.replacingOccurrences(of: "\"]", with: "]")
                inputs = inputs.replacingOccurrences(of: "\"{", with: "{")
                inputs = inputs.replacingOccurrences(of: "}\"", with: "}")
                inputs = inputs.replacingOccurrences(of: "\\", with: "")
                let receiver = "\"\(vc.addressToPay)\":\(vc.rounded(number: amount))"
                let param = "''\(inputs)'', ''{\(receiver)}'', 0, true"
                Reducer.makeCommand(command: .createrawtransaction, param: param) { [unowned vc = self] (response, errorMessage) in
                    if let unsignedRawTx1 = response as? String {
                        let param = "\"\(unsignedRawTx1)\", { \"includeWatching\":\(spendFromCold), \"subtractFeeFromOutputs\":[0], \"changeAddress\": \"\(self.addressToPay)\", \"replaceable\": true, \"conf_target\": \(vc.numberOfBlocks) }"
                        Reducer.makeCommand(command: .fundrawtransaction, param: param) { [unowned vc = self] (response, errorMessage) in
                            if let result = response as? NSDictionary {
                                if spendFromCold {
                                    vc.unsignedRawTx = result["hex"] as! String
                                    completion()
                                } else {
                                    Reducer.makeCommand(command: .signrawtransactionwithwallet, param: "\"\(result["hex"] as! String)\"") { [unowned vc = self] (response, errorMessage) in
                                        if let dict = response as? NSDictionary {
                                            vc.signedRawTx = dict["hex"] as! String
                                            completion()
                                        } else {
                                            vc.errorBool = true
                                            vc.errorDescription = errorMessage ?? ""
                                            completion()
                                        }
                                    }
                                }
                            } else {
                                vc.errorBool = true
                                vc.errorDescription = errorMessage ?? ""
                                completion()
                            }
                        }
                    } else {
                        vc.errorBool = true
                        vc.errorDescription = errorMessage ?? ""
                        completion()
                    }
                }
            } else {
                vc.errorBool = true
                vc.errorDescription = errorMessage ?? ""
                completion()
            }
        }
    }
}
