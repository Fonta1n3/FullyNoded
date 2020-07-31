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
    
    func createRawTransaction(completion: @escaping ((signedTx: String?, psbt: String?, errorDescription: String?)) -> Void) {
        
        func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
            Reducer.makeCommand(command: method, param: param) { (response, errorMessage) in
                if errorMessage == nil {
                    
                    switch method {
                        
                    case .createpsbt:
                        if let psbt = response as? String {
                            Signer.sign(psbt: psbt) { (psbt, rawTx, errorMessage) in
                                completion((rawTx, psbt, errorMessage))
                            }
                        }
                        
                    default:
                        break
                    }
                    
                } else {
                    completion((nil, nil, errorMessage ?? "error creating tx with utxo"))
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
        
        executeNodeCommand(method: .createpsbt, param: param)
        
    }
    
}
