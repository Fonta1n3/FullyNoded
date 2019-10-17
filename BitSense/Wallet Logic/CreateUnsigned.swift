//
//  CreateUnsigned.swift
//  BitSense
//
//  Created by Peter on 04/05/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class CreateUnsigned {
    
    var amount = Double()
    var changeAddress = ""
    var addressToPay = ""
    var spendingAddress = ""
    var spendableUtxos = [NSDictionary]()
    var inputArray = [Any]()
    var utxoTxId = String()
    var utxoVout = Int()
    var changeAmount = Double()
    var inputs = ""
    var unsignedRawTx = ""
    var errorBool = Bool()
    var errorDescription = ""
    
    var optimized = false
    
    func createRawTransaction(completion: @escaping () -> Void) {
        
        let reducer = Reducer()
        
        func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
            
            func getResult() {
                
                if !reducer.errorBool {
                    
                    switch method {
                        
                    case .listunspent:
                        
                        let resultArray = reducer.arrayToReturn
                        parseUnspent(utxos: resultArray)
                        
                    case .createrawtransaction:
                        
                        if !optimized {
                            
                            let originalTx = reducer.stringToReturn
                            
                            optimizeTheFee(raw: originalTx,
                                           amount: amount,
                                           addressToPay: addressToPay,
                                           sweep: false,
                                           inputArray: inputArray,
                                           changeAddress: changeAddress,
                                           changeAmount: changeAmount)
                            
                        } else {
                            
                            unsignedRawTx = reducer.stringToReturn
                            completion()
                            
                        }
                        
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
        
        func parseUnspent(utxos: NSArray) {
            
            if utxos.count > 0 {
                
                parseUtxos(resultArray: utxos)
                
                var loop = true
                
                self.inputArray.removeAll()
                
                if self.spendableUtxos.count > 0 {
                    
                    var sumOfUtxo = 0.0
                    
                    for spendable in self.spendableUtxos {
                        
                        if loop {
                            
                            let amountAvailable = spendable["amount"] as! Double
                            sumOfUtxo = sumOfUtxo + amountAvailable
                            
                            if sumOfUtxo < (self.amount + 0.00050000) {
                                
                                self.utxoTxId = spendable["txid"] as! String
                                self.utxoVout = spendable["vout"] as! Int
                                let input = "{\"txid\":\"\(self.utxoTxId)\",\"vout\": \(self.utxoVout),\"sequence\": 1}"
                                self.inputArray.append(input)
                                
                            } else {
                                
                                loop = false
                                self.utxoTxId = spendable["txid"] as! String
                                self.utxoVout = spendable["vout"] as! Int
                                let input = "{\"txid\":\"\(self.utxoTxId)\",\"vout\": \(self.utxoVout),\"sequence\": 1}"
                                self.inputArray.append(input)
                                self.changeAmount = sumOfUtxo - (self.amount + 0.00050000)
                                self.changeAmount = Double(round(100000000*self.changeAmount)/100000000)
                                
                                processInputs()
                                
                                let receiver = "\"\(self.addressToPay)\":\(self.amount)"
                                let change = "\"\(self.changeAddress)\":\(self.changeAmount)"
                                var param = "''\(self.inputs)'', ''{\(receiver), \(change)}'', 0, true"
                                param = param.replacingOccurrences(of: "\"{", with: "{")
                                param = param.replacingOccurrences(of: "}\"", with: "}")
                                
                                executeNodeCommand(method: BTC_CLI_COMMAND.createrawtransaction,
                                                      param: param)
                                
                            }
                            
                        }
                        
                    }
                    
                }
                
            } else {
                
                errorBool = true
                errorDescription = "No UTXO's"
                completion()
                
            }
            
        }
        
        func parseUtxos(resultArray: NSArray) {
            
            for utxo in resultArray {
                
                if let utxoDict = utxo as? NSDictionary {
                    
                    if let _ = utxoDict["txid"] as? String {
                        
                        self.spendableUtxos.append(utxoDict)
                        
                    }
                    
                }
                
            }
            
        }
        
        func processInputs() {
            
            self.inputs = self.inputArray.description
            self.inputs = self.inputs.replacingOccurrences(of: "[\"", with: "[")
            self.inputs = self.inputs.replacingOccurrences(of: "\"]", with: "]")
            self.inputs = self.inputs.replacingOccurrences(of: "\"{", with: "{")
            self.inputs = self.inputs.replacingOccurrences(of: "}\"", with: "}")
            self.inputs = self.inputs.replacingOccurrences(of: "\\", with: "")
            
        }
        
        func optimizeTheFee(raw: String, amount: Double, addressToPay: String, sweep: Bool, inputArray: [Any], changeAddress: String, changeAmount: Double) {
            
            let getSmartFee = GetSmartFee()
            getSmartFee.rawSigned = raw
            getSmartFee.isUnsigned = true
            
            func getFeeResult() {
                
                let optimalFee = rounded(number: getSmartFee.optimalFee)
                
                self.changeAmount = (changeAmount + 0.00050000) - optimalFee
                self.changeAmount = rounded(number: self.changeAmount)
                self.amount = amount
                self.optimized = true
                
                let receiver = "\"\(self.addressToPay)\":\(self.amount)"
                let change = "\"\(self.changeAddress)\":\(self.changeAmount)"
                var param = "''\(self.inputs)'', ''{\(receiver), \(change)}'', 0, true"
                param = param.replacingOccurrences(of: "\"{", with: "{")
                param = param.replacingOccurrences(of: "}\"", with: "}")
                
                executeNodeCommand(method: BTC_CLI_COMMAND.createrawtransaction,
                                      param: param)
                
            }
            
            getSmartFee.getSmartFee(completion: getFeeResult)
            
        }
        
        executeNodeCommand(method: BTC_CLI_COMMAND.listunspent,
                              param: "1, 9999999, [\"\(self.spendingAddress)\"]")
        
    }
    
}
