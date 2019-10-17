//
//  SendUTXO.swift
//  BitSense
//
//  Created by Peter on 21/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class SendUTXO {
    
    var amount = Double()
    var changeAddress = ""
    var addressToPay = ""
    var sweep = Bool()
    var spendableUtxos = [NSDictionary]()
    var inputArray = [Any]()
    var utxoTxId = String()
    var utxoVout = Int()
    var changeAmount = Double()
    var inputs = ""
    var signedRawTx = ""
    var errorBool = Bool()
    var errorDescription = ""
    
    func createRawTransaction(completion: @escaping () -> Void) {
        
        let reducer = Reducer()
        
        func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
            
            func getResult() {
                
                if !reducer.errorBool {
                    
                    switch method {
                        
                    case .signrawtransactionwithwallet:
                        
                        let dict = reducer.dictToReturn
                        signedRawTx = dict["hex"] as! String
                        completion()
                        
                    case .createrawtransaction:
                        
                        let unsignedRawTx = reducer.stringToReturn
                        executeNodeCommand(method: BTC_CLI_COMMAND.signrawtransactionwithwallet, param: "\"\(unsignedRawTx)\"")
                        
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
        
        func processInputs() {
            
            self.inputs = self.inputArray.description
            self.inputs = self.inputs.replacingOccurrences(of: "[\"", with: "[")
            self.inputs = self.inputs.replacingOccurrences(of: "\"]", with: "]")
            self.inputs = self.inputs.replacingOccurrences(of: "\"{", with: "{")
            self.inputs = self.inputs.replacingOccurrences(of: "}\"", with: "}")
            self.inputs = self.inputs.replacingOccurrences(of: "\\", with: "")
            
        }
        
        processInputs()
        
        var param = ""
        
        if !sweep {
            
            let receiver = "\"\(self.addressToPay)\":\(self.amount)"
            let change = "\"\(self.changeAddress)\":\(self.changeAmount)"
            param = "''\(self.inputs)'', ''{\(receiver), \(change)}''"
            param = param.replacingOccurrences(of: "\"{", with: "{")
            param = param.replacingOccurrences(of: "}\"", with: "}")
            
        } else {
            
            let receiver = "\"\(self.addressToPay)\":\(self.amount)"
            param = "''\(self.inputs)'', ''{\(receiver)}''"
            param = param.replacingOccurrences(of: "\"{", with: "{")
            param = param.replacingOccurrences(of: "}\"", with: "}")
            
        }
        
        executeNodeCommand(method: BTC_CLI_COMMAND.createrawtransaction,
                           param: param)
        
    }
    
}
