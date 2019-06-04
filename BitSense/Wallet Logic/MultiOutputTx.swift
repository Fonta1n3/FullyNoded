//
//  MultiOutputTx.swift
//  BitSense
//
//  Created by Peter on 27/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class MultiOutputTx {
    
    let makeSSHCall = SSHelper()
    var miningFee = Double()
    var amount = Double()
    var changeAddress = ""
    var spendableUtxos = [NSDictionary]()
    var inputArray = [Any]()
    var utxoTxId = String()
    var utxoVout = Int()
    var changeAmount = Double()
    var inputs = ""
    var outputs = ""
    var ssh:SSHService!
    var signedRawTx = ""
    var errorBool = Bool()
    var errorDescription = ""
    
    func createRawTransaction(completion: @escaping () -> Void) {
        
        func executeNodeCommandSsh(method: BTC_CLI_COMMAND, param: String) {
            
            func getResult() {
                
                if !makeSSHCall.errorBool {
                    
                    switch method {
                        
                    case BTC_CLI_COMMAND.signrawtransaction:
                        
                        let dict = makeSSHCall.dictToReturn
                        signedRawTx = dict["hex"] as! String
                        completion()
                        
                    case BTC_CLI_COMMAND.listunspent:
                        
                        let resultArray = makeSSHCall.arrayToReturn
                        parseUnspent(utxos: resultArray)
                        
                    case BTC_CLI_COMMAND.createrawtransaction:
                        
                        let unsignedRawTx = makeSSHCall.stringToReturn
                        executeNodeCommandSsh(method: BTC_CLI_COMMAND.signrawtransaction, param: "\'\(unsignedRawTx)\'")
                        
                    default:
                        
                        break
                        
                    }
                    
                } else {
                    
                    errorBool = true
                    errorDescription = makeSSHCall.errorDescription
                    completion()
                    
                }
                
            }
            
            if ssh.session.isConnected {
                
                makeSSHCall.executeSSHCommand(ssh: ssh,
                                              method: method,
                                              param: param,
                                              completion: getResult)
                
            } else {
                
                errorBool = true
                errorDescription = "Not connected"
                completion()
                
            }
            
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
                                print("amountAvailable = \(amountAvailable)")
                                sumOfUtxo = sumOfUtxo + amountAvailable
                                
                                if sumOfUtxo < (self.amount + miningFee) {
                                    
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
                                    //ensure change amount is losing the mining fee
                                    self.changeAmount = sumOfUtxo - (self.amount + miningFee)
                                    print("sumofutxo = \(sumOfUtxo)")
                                    print("amount = \(self.amount)")
                                    print("miningfee = \(miningFee)")
                                    print("changeamount = \(self.changeAmount)")
                                    self.changeAmount = Double(round(100000000*self.changeAmount)/100000000)
                                    print("changeamount = \(self.changeAmount)")
                                    
                                    processInputs()
                                    
                                    //let param = "\'\(self.inputs)\' \'{\"\(self.addressToPay)\":\(self.amount), \"\(self.changeAddress)\": \(self.changeAmount)}\'"
                                    let param = "\'\(self.inputs)\' \'{\(self.outputs), \"\(self.changeAddress)\": \(self.changeAmount)}\'"
                                    
                                    executeNodeCommandSsh(method: BTC_CLI_COMMAND.createrawtransaction,
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
                        
                        if let spendableCheck = utxoDict["spendable"] as? Bool {
                            
                            if spendableCheck {
                                
                                if let _ = utxoDict["vout"] as? Int {
                                    
                                    if let _ = utxoDict["amount"] as? Double {
                                        
                                        self.spendableUtxos.append(utxoDict)
                                        
                                    }
                                    
                                }
                                
                            }
                            
                        }
                        
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
        
        executeNodeCommandSsh(method: BTC_CLI_COMMAND.listunspent, param: "")
        
    }
}
