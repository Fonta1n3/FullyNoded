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
    var ssh:SSHService!
    var isUsingSSH = Bool()
    var torRPC:MakeRPCCall!
    var torClient:TorClient!
    
    var amount = Double()
    var addressToPay = ""
    var spendableUtxos = [NSDictionary]()
    var inputArray = [Any]()
    var utxoTxId = String()
    var utxoVout = Int()
    var inputs = ""
    var psbt = ""
    var errorBool = Bool()
    var errorDescription = ""
    var noInputs = Bool()
    var spendingAddress = ""
    var changeAddress = ""
    var changeAmount = Double()
    var miningFee = Double()
    
    func createPSBTNow(completion: @escaping () -> Void) {
        
        func executeNodeCommandSsh(method: BTC_CLI_COMMAND, param: String) {
            
            func getResult() {
                
                if !makeSSHCall.errorBool {
                    
                    switch method {
                        
                    case BTC_CLI_COMMAND.listunspent:
                        
                        let resultArray = makeSSHCall.arrayToReturn
                        parseUnspent(utxos: resultArray)
                        
                    case BTC_CLI_COMMAND.createpsbt:
                        
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
            
            if ssh != nil {
             
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
            
        }
        
        func parseUnspent(utxos: NSArray) {
            
            if utxos.count > 0 {
                
                var loop = true
                self.inputArray.removeAll()
                
                //if self.spendableUtxos.count > 0 {
                    
                    var sumOfUtxo = 0.0
                    
                    for utxoDict in utxos {
                        
                        print("spendable")
                        
                        let utxo = utxoDict as! NSDictionary
                        
                        if loop {
                            
                            let amountAvailable = utxo["amount"] as! Double
                            sumOfUtxo = sumOfUtxo + amountAvailable
                            
                            if sumOfUtxo < self.amount {
                                
                                self.utxoTxId = utxo["txid"] as! String
                                self.utxoVout = utxo["vout"] as! Int
                                let input = "{\"txid\":\"\(self.utxoTxId)\",\"vout\": \(self.utxoVout),\"sequence\": 1}"
                                self.inputArray.append(input)
                                
                            } else {
                                
                                loop = false
                                self.utxoTxId = utxo["txid"] as! String
                                self.utxoVout = utxo["vout"] as! Int
                                let input = "{\"txid\":\"\(self.utxoTxId)\",\"vout\": \(self.utxoVout),\"sequence\": 1}"
                                self.inputArray.append(input)
                                self.processInputs()
                                
                                self.changeAmount = sumOfUtxo - (self.amount + miningFee)
                                self.changeAmount = Double(round(100000000*self.changeAmount)/100000000)
                                
                                let param = "''\(self.inputs)'', ''[{\"\(self.addressToPay)\":\(self.amount)}, {\"\(self.changeAddress)\":\(self.changeAmount)}]'', 0, true"
                                
                                executeNodeCommandSsh(method: BTC_CLI_COMMAND.createpsbt,
                                                      param: param)
                                
                            }
                            
                        }
                        
                    }
                    
                //}
                
            } else {
                
                errorBool = true
                errorDescription = "No UTXO's"
                completion()
                
            }
            
        }
        
        let miningFeeCheck = UserDefaults.standard.object(forKey: "miningFee") as! String
        var miningFeeString = ""
        miningFeeString = miningFeeCheck
        miningFeeString = miningFeeString.replacingOccurrences(of: ",", with: "")
        let fee = (Double(miningFeeString)!) / 100000000
        miningFee = fee
        
        executeNodeCommandSsh(method: BTC_CLI_COMMAND.listunspent,
                              param: "1, 9999999, [\"\(self.spendingAddress)\"]")
        
    }
    
    func processInputs() {
        
        self.inputs = self.inputArray.description
        self.inputs = self.inputs.replacingOccurrences(of: "[\"", with: "[")
        self.inputs = self.inputs.replacingOccurrences(of: "\"]", with: "]")
        self.inputs = self.inputs.replacingOccurrences(of: "\"{", with: "{")
        self.inputs = self.inputs.replacingOccurrences(of: "}\"", with: "}")
        self.inputs = self.inputs.replacingOccurrences(of: "\\", with: "")
        
    }
    
}
