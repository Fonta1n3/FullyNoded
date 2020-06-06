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
        
        let reducer = Reducer()
        
        func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
            
            func getResult() {
                
                if !reducer.errorBool {
                    
                    switch method {
                        
                    case .signrawtransactionwithwallet:
                        
                        let dict = reducer.dictToReturn
                        signedRawTx = dict["hex"] as! String
                        completion()
                        
                    case .fundrawtransaction:
                        
                        let result = reducer.dictToReturn
                        let unsignedRawTx = result["hex"] as! String
                        
                        executeNodeCommand(method: .signrawtransactionwithwallet,
                                              param: "\"\(unsignedRawTx)\"")
                        
                    case .createrawtransaction:
                        
                        let unsignedRawTx = reducer.stringToReturn
                        
                        let param = "\"\(unsignedRawTx)\", { \"includeWatching\":false, \"subtractFeeFromOutputs\":[], \"replaceable\": true, \"conf_target\": \(numberOfBlocks) }"
                            
                        executeNodeCommand(method: .fundrawtransaction,
                                              param: param)
                        
                    default:
                        
                        break
                        
                    }
                    
                } else {
                    
                    errorBool = true
                    errorDescription = reducer.errorDescription
                    completion()
                    
                }
                
            }
            
            reducer.makeCommand(command: method,
                                param: param,
                                completion: getResult)
            
        }
        
        
        
        let receiver = "\"\(self.addressToPay)\":\(self.amount)"
        let param = "''[]'', ''{\(receiver)}'', 0, true"
        
        executeNodeCommand(method: BTC_CLI_COMMAND.createrawtransaction, param: param)
        
    }
    
    func createRawTransactionFromColdWallet(completion: @escaping () -> Void) {
        
        let reducer = Reducer()
        
        func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
            
            func getResult() {
                
                if !reducer.errorBool {
                    
                    switch method {
                        
                    case .fundrawtransaction:
                        
                        let result = reducer.dictToReturn
                        unsignedRawTx = result["hex"] as! String
                        completion()
                       
                        
                    case .createrawtransaction:
                        
                        let unsignedRawTx = reducer.stringToReturn
                        
                        let param = "\"\(unsignedRawTx)\", { \"includeWatching\":true, \"subtractFeeFromOutputs\":[], \"replaceable\": true, \"conf_target\": \(numberOfBlocks) }"
                            
                        executeNodeCommand(method: BTC_CLI_COMMAND.fundrawtransaction,
                                           param: param)
                        
                    default:
                        
                        break
                        
                    }
                    
                } else {
                    
                    errorBool = true
                    errorDescription = reducer.errorDescription
                    completion()
                    
                }
                
            }
            
            reducer.makeCommand(command: method, param: param, completion: getResult)
            
        }
        
        let receiver = "\"\(self.addressToPay)\":\(self.amount)"
        let param = "''[]'', ''{\(receiver)}'', 0, true"
        executeNodeCommand(method: .createrawtransaction, param: param)
        
    }
    
    func createBatchRawTransactionFromHotWallet(completion: @escaping () -> Void) {
        
        let reducer = Reducer()
        
        func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
            
            func getResult() {
                
                if !reducer.errorBool {
                    
                    switch method {
                        
                    case .signrawtransactionwithwallet:
                        
                        let dict = reducer.dictToReturn
                        signedRawTx = dict["hex"] as! String
                        completion()
                        
                    case .fundrawtransaction:
                        
                        let result = reducer.dictToReturn
                        let unsignedRawTx = result["hex"] as! String
                        
                        executeNodeCommand(method: BTC_CLI_COMMAND.signrawtransactionwithwallet,
                                              param: "\"\(unsignedRawTx)\"")
                        
                    case .createrawtransaction:
                        
                        let unsignedRawTx = reducer.stringToReturn
                        
                        let param = "\"\(unsignedRawTx)\", { \"includeWatching\":false, \"subtractFeeFromOutputs\":[], \"replaceable\": true, \"conf_target\": \(numberOfBlocks) }"
                            
                        executeNodeCommand(method: BTC_CLI_COMMAND.fundrawtransaction,
                                              param: param)
                        
                    default:
                        
                        break
                        
                    }
                    
                } else {
                    
                    errorBool = true
                    errorDescription = reducer.errorDescription
                    completion()
                    
                }
                
            }
            
            reducer.makeCommand(command: method,
                                param: param,
                                completion: getResult)
            
        }
        
        let param = "''[]'', ''{\(self.outputs)}'', 0, true"
        executeNodeCommand(method: .createrawtransaction, param: param)
        
    }
    
    func createBatchRawTransactionFromColdWallet(completion: @escaping () -> Void) {
        
        let reducer = Reducer()
        
        func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
            
            func getResult() {
                
                if !reducer.errorBool {
                    
                    switch method {
                        
                    case .fundrawtransaction:
                        
                        let result = reducer.dictToReturn
                        unsignedRawTx = result["hex"] as! String
                        completion()
                        
                        
                    case .createrawtransaction:
                        
                        let unsignedRawTx = reducer.stringToReturn
                        
                        let param = "\"\(unsignedRawTx)\", { \"includeWatching\":true, \"subtractFeeFromOutputs\":[], \"replaceable\": true, \"conf_target\": \(numberOfBlocks) }"
                        
                        executeNodeCommand(method: BTC_CLI_COMMAND.fundrawtransaction,
                                           param: param)
                        
                    default:
                        
                        break
                        
                    }
                    
                } else {
                    
                    errorBool = true
                    errorDescription = reducer.errorDescription
                    completion()
                    
                }
                
            }
            
            reducer.makeCommand(command: method,
                                param: param,
                                completion: getResult)
            
        }
        
        let param = "''[]'', ''{\(self.outputs)}'', 0, true"
        
        executeNodeCommand(method: BTC_CLI_COMMAND.createrawtransaction,
                           param: param)
        
    }
    
    func sweepRawTx(completion: @escaping () -> Void) {
        
        let reducer = Reducer()
        reducer.makeCommand(command: .listunspent, param: "0") { [unowned vc = self] in
            if !reducer.errorBool {
                let resultArray = reducer.arrayToReturn
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
                reducer.makeCommand(command: .createrawtransaction, param: param) { [unowned vc = self] in
                    if !reducer.errorBool {
                        let unsignedRawTx1 = reducer.stringToReturn
                        let param = "\"\(unsignedRawTx1)\", { \"includeWatching\":\(spendFromCold), \"subtractFeeFromOutputs\":[0], \"changeAddress\": \"\(self.addressToPay)\", \"replaceable\": true, \"conf_target\": \(vc.numberOfBlocks) }"
                        reducer.makeCommand(command: .fundrawtransaction, param: param) { [unowned vc = self] in
                            if !reducer.errorBool {
                                let result = reducer.dictToReturn
                                if spendFromCold {
                                    vc.unsignedRawTx = result["hex"] as! String
                                    completion()
                                } else {
                                    reducer.makeCommand(command: .signrawtransactionwithwallet, param: "\"\(result["hex"] as! String)\"") { [unowned vc = self] in
                                        if !reducer.errorBool {
                                            let dict = reducer.dictToReturn
                                            vc.signedRawTx = dict["hex"] as! String
                                            completion()
                                        } else {
                                            vc.errorBool = true
                                            vc.errorDescription = reducer.errorDescription
                                            completion()
                                        }
                                    }
                                }
                            } else {
                                vc.errorBool = true
                                vc.errorDescription = reducer.errorDescription
                                completion()
                            }
                        }
                    } else {
                        vc.errorBool = true
                        vc.errorDescription = reducer.errorDescription
                        completion()
                    }
                }
            } else {
                vc.errorBool = true
                vc.errorDescription = reducer.errorDescription
                completion()
            }
            
        }
    }
    
}
