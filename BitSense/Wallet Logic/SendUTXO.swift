//
//  SendUTXO.swift
//  BitSense
//
//  Created by Peter on 21/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class SendUTXO {
    
    var makeSSHCall:SSHelper!
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
    var ssh:SSHService!
    var signedRawTx = ""
    var errorBool = Bool()
    var errorDescription = ""
    var isUsingSSH = Bool()
    var torClient:TorClient!
    var torRPC:MakeRPCCall!
    
    func createRawTransaction(completion: @escaping () -> Void) {
        
        func executeNodeCommandSsh(method: BTC_CLI_COMMAND, param: String) {
            
            func getResult() {
                
                if !makeSSHCall.errorBool {
                    
                    switch method {
                        
                    case BTC_CLI_COMMAND.signrawtransactionwithwallet:
                        
                        let dict = makeSSHCall.dictToReturn
                        signedRawTx = dict["hex"] as! String
                        completion()
                        
                    case BTC_CLI_COMMAND.createrawtransaction:
                        
                        let unsignedRawTx = makeSSHCall.stringToReturn
                        executeNodeCommandSsh(method: BTC_CLI_COMMAND.signrawtransactionwithwallet, param: "\"\(unsignedRawTx)\"")
                        
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
                
            } else {
                
                errorBool = true
                errorDescription = "Not connected"
                completion()
                
            }
            
        }
        
        func executeNodeCommandTor(method: BTC_CLI_COMMAND, param: String) {
            
            func getResult() {
                
                if !torRPC.errorBool {
                    
                    switch method {
                        
                    case BTC_CLI_COMMAND.signrawtransactionwithwallet:
                        
                        let dict = torRPC.dictToReturn
                        signedRawTx = dict["hex"] as! String
                        completion()
                        
                    case BTC_CLI_COMMAND.createrawtransaction:
                        
                        let unsignedRawTx = torRPC.stringToReturn
                        executeNodeCommandTor(method: BTC_CLI_COMMAND.signrawtransactionwithwallet, param: "\"\(unsignedRawTx)\"")
                        
                    default:
                        
                        break
                        
                    }
                    
                } else {
                    
                    errorBool = true
                    errorDescription = torRPC.errorDescription
                    completion()
                    
                }
                
            }
            
            if self.torClient.isOperational {
                
                self.torRPC.executeRPCCommand(method: method,
                                              param: param,
                                              completion: getResult)
                
            } else {
                
                errorBool = true
                errorDescription = "Not connected"
                completion()
                
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
        
        if isUsingSSH {
            
            executeNodeCommandSsh(method: BTC_CLI_COMMAND.createrawtransaction,
                                  param: param)
            
        } else {
            
            executeNodeCommandTor(method: BTC_CLI_COMMAND.createrawtransaction,
                                  param: param)
            
        }
        
    }
    
}
