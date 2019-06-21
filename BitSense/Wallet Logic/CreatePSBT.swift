//
//  CreatePSBT.swift
//  BitSense
//
//  Created by Peter on 12/06/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class CreatePSBT {
    
    var makeSSHCall:SSHelper!
    var amount = Double()
    var addressToPay = ""
    var spendableUtxos = [NSDictionary]()
    var inputArray = [Any]()
    var utxoTxId = String()
    var utxoVout = Int()
    var inputs = ""
    var ssh:SSHService!
    var psbt = ""
    var errorBool = Bool()
    var errorDescription = ""
    
    func createPSBT(completion: @escaping () -> Void) {
        
        func executeNodeCommandSsh(method: BTC_CLI_COMMAND, param: String) {
            
            func getResult() {
                
                if !makeSSHCall.errorBool {
                    
                    switch method {
                        
                    case BTC_CLI_COMMAND.listunspent:
                        
                        let resultArray = makeSSHCall.arrayToReturn
                        parseUnspent(utxos: resultArray)
                        
                    case BTC_CLI_COMMAND.walletcreatefundedpsbt:
                        
                        psbt = makeSSHCall.stringToReturn
                        completion()
                        
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
                
                //parseUtxos(resultArray: utxos)
                
                var loop = true
                
                self.inputArray.removeAll()
                
                if self.spendableUtxos.count > 0 {
                    
                    var sumOfUtxo = 0.0
                    
                    for spendable in self.spendableUtxos {
                        
                        if loop {
                            
                            let amountAvailable = spendable["amount"] as! Double
                            sumOfUtxo = sumOfUtxo + amountAvailable
                            
                            if sumOfUtxo < self.amount {
                                
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
                                
                                //processInputs()
                                
                                let param = "\"[\"\(self.inputs)\"]\" \"[{\"\(self.addressToPay)\":\(self.amount)}]\""
                                
                                executeNodeCommandSsh(method: BTC_CLI_COMMAND.walletcreatefundedpsbt,
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
        
        
        
        let param = "\"[]\" \"[{\\\"\(self.addressToPay)\\\":\(self.amount)}]\""
        
        executeNodeCommandSsh(method: BTC_CLI_COMMAND.walletcreatefundedpsbt,
                              param: param)
        
    }
    
}
