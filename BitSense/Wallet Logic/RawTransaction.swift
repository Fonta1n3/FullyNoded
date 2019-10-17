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
        
        
        
        let receiver = "\"\(self.addressToPay)\":\(self.amount)"
        let param = "''[]'', ''{\(receiver)}'', 0, true"
        
        executeNodeCommand(method: BTC_CLI_COMMAND.createrawtransaction,
                           param: param)
        
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
            
            reducer.makeCommand(command: method,
                                param: param,
                                completion: getResult)
            
        }
        
        let receiver = "\"\(self.addressToPay)\":\(self.amount)"
        let param = "''[]'', ''{\(receiver)}'', 0, true"
        
        executeNodeCommand(method: BTC_CLI_COMMAND.createrawtransaction,
                           param: param)
        
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
        
        executeNodeCommand(method: BTC_CLI_COMMAND.createrawtransaction,
                           param: param)
        
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
    
}
