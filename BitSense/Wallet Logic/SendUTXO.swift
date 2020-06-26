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
        func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
            Reducer.makeCommand(command: method, param: param) { [unowned vc = self] (response, errorMessage) in
                if errorMessage == nil {
                    switch method {
                    case .signrawtransactionwithwallet:
                        if let dict = response as? NSDictionary {
                            vc.signedRawTx = dict["hex"] as! String
                            completion()
                        }
                    case .createrawtransaction:
                        if let unsignedRawTx = response as? String {
                            executeNodeCommand(method: .signrawtransactionwithwallet, param: "\"\(unsignedRawTx)\"")
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
        
        func processInputs() {
            inputs = inputArray.description
            inputs = inputs.replacingOccurrences(of: "[\"", with: "[")
            inputs = inputs.replacingOccurrences(of: "\"]", with: "]")
            inputs = inputs.replacingOccurrences(of: "\"{", with: "{")
            inputs = inputs.replacingOccurrences(of: "}\"", with: "}")
            inputs = inputs.replacingOccurrences(of: "\\", with: "")
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
