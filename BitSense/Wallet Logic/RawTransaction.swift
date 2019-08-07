//
//  RawTransaction.swift
//  BitSense
//
//  Created by Peter on 20/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class RawTransaction {
    
    let makeSSHCall = SSHelper()
    var amount = Double()
    var addressToPay = ""
    var ssh:SSHService!
    var signedRawTx = ""
    var unsignedRawTx = ""
    var errorBool = Bool()
    var errorDescription = ""
    var isUsingSSH = Bool()
    var torClient:TorClient!
    var torRPC:MakeRPCCall!
    var numberOfBlocks = Int()
    var outputs = ""
    
    func createRawTransactionFromHotWallet(completion: @escaping () -> Void) {
        
        func executeNodeCommandSsh(method: BTC_CLI_COMMAND, param: String) {
            
            func getResult() {
                
                if !makeSSHCall.errorBool {
                    
                    switch method {
                        
                    case BTC_CLI_COMMAND.signrawtransactionwithwallet:
                        
                        let dict = makeSSHCall.dictToReturn
                        signedRawTx = dict["hex"] as! String
                        completion()
                        
                    case BTC_CLI_COMMAND.fundrawtransaction:
                        
                        let result = makeSSHCall.dictToReturn
                        let unsignedRawTx = result["hex"] as! String
                        
                        executeNodeCommandSsh(method: BTC_CLI_COMMAND.signrawtransactionwithwallet,
                                              param: "\"\(unsignedRawTx)\"")
                        
                    case BTC_CLI_COMMAND.createrawtransaction:
                        
                        let unsignedRawTx = makeSSHCall.stringToReturn
                        
                        executeNodeCommandSsh(method: BTC_CLI_COMMAND.fundrawtransaction,
                                              param: "\"\(unsignedRawTx)\", { \"includeWatching\":false, \"replaceable\": true, \"conf_target\": \(numberOfBlocks) }")
                        
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
                        
                    case BTC_CLI_COMMAND.fundrawtransaction:
                        
                        let result = torRPC.dictToReturn
                        let unsignedRawTx = result["hex"] as! String
                        
                        executeNodeCommandTor(method: BTC_CLI_COMMAND.signrawtransactionwithwallet,
                                              param: "\"\(unsignedRawTx)\"")
                        
                    case BTC_CLI_COMMAND.createrawtransaction:
                        
                        let unsignedRawTx = torRPC.stringToReturn
                        
                        executeNodeCommandTor(method: BTC_CLI_COMMAND.fundrawtransaction,
                                              param: "\"\(unsignedRawTx)\", { \"includeWatching\":false, \"replaceable\": true, \"conf_target\": \(numberOfBlocks) }")
                        
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
        
        let receiver = "\"\(self.addressToPay)\":\(self.amount)"
        let param = "''[]'', ''{\(receiver)}'', 0, true"
        
        if isUsingSSH {
            
            executeNodeCommandSsh(method: BTC_CLI_COMMAND.createrawtransaction,
                                  param: param)
            
        } else {
            
            executeNodeCommandTor(method: BTC_CLI_COMMAND.createrawtransaction,
                                  param: param)
            
        }
        
    }
    
    func createRawTransactionFromColdWallet(completion: @escaping () -> Void) {
        
        func executeNodeCommandSsh(method: BTC_CLI_COMMAND, param: String) {
            
            func getResult() {
                
                if !makeSSHCall.errorBool {
                    
                    switch method {
                        
                    case BTC_CLI_COMMAND.fundrawtransaction:
                        
                        let result = makeSSHCall.dictToReturn
                        unsignedRawTx = result["hex"] as! String
                        completion()
                       
                        
                    case BTC_CLI_COMMAND.createrawtransaction:
                        
                        let unsignedRawTx = makeSSHCall.stringToReturn
                        
                        executeNodeCommandSsh(method: BTC_CLI_COMMAND.fundrawtransaction,
                                              param: "\"\(unsignedRawTx)\", { \"includeWatching\":true, \"replaceable\": true, \"conf_target\": \(numberOfBlocks) }")
                        
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
                        
                    case BTC_CLI_COMMAND.fundrawtransaction:
                        
                        let result = torRPC.dictToReturn
                        unsignedRawTx = result["hex"] as! String
                        completion()
                        
                        
                    case BTC_CLI_COMMAND.createrawtransaction:
                        
                        let unsignedRawTx = torRPC.stringToReturn
                        
                        executeNodeCommandTor(method: BTC_CLI_COMMAND.fundrawtransaction,
                                              param: "\"\(unsignedRawTx)\", { \"includeWatching\":true, \"replaceable\": true, \"conf_target\": \(numberOfBlocks) }")
                        
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
        
        let receiver = "\"\(self.addressToPay)\":\(self.amount)"
        let param = "''[]'', ''{\(receiver)}'', 0, true"
        
        if isUsingSSH {
            
            executeNodeCommandSsh(method: BTC_CLI_COMMAND.createrawtransaction,
                                  param: param)
            
        } else {
            
            executeNodeCommandTor(method: BTC_CLI_COMMAND.createrawtransaction,
                                  param: param)
            
        }
        
    }
    
    func createBatchRawTransactionFromHotWallet(completion: @escaping () -> Void) {
        
        func executeNodeCommandSsh(method: BTC_CLI_COMMAND, param: String) {
            
            func getResult() {
                
                if !makeSSHCall.errorBool {
                    
                    switch method {
                        
                    case BTC_CLI_COMMAND.signrawtransactionwithwallet:
                        
                        let dict = makeSSHCall.dictToReturn
                        signedRawTx = dict["hex"] as! String
                        completion()
                        
                    case BTC_CLI_COMMAND.fundrawtransaction:
                        
                        let result = makeSSHCall.dictToReturn
                        let unsignedRawTx = result["hex"] as! String
                        
                        executeNodeCommandSsh(method: BTC_CLI_COMMAND.signrawtransactionwithwallet,
                                              param: "\"\(unsignedRawTx)\"")
                        
                    case BTC_CLI_COMMAND.createrawtransaction:
                        
                        let unsignedRawTx = makeSSHCall.stringToReturn
                        
                        executeNodeCommandSsh(method: BTC_CLI_COMMAND.fundrawtransaction,
                                              param: "\"\(unsignedRawTx)\", { \"includeWatching\":false, \"replaceable\": true, \"conf_target\": \(numberOfBlocks) }")
                        
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
                        
                    case BTC_CLI_COMMAND.fundrawtransaction:
                        
                        let result = torRPC.dictToReturn
                        let unsignedRawTx = result["hex"] as! String
                        
                        executeNodeCommandTor(method: BTC_CLI_COMMAND.signrawtransactionwithwallet,
                                              param: "\"\(unsignedRawTx)\"")
                        
                    case BTC_CLI_COMMAND.createrawtransaction:
                        
                        let unsignedRawTx = torRPC.stringToReturn
                        
                        executeNodeCommandTor(method: BTC_CLI_COMMAND.fundrawtransaction,
                                              param: "\"\(unsignedRawTx)\", { \"includeWatching\":false, \"replaceable\": true, \"conf_target\": \(numberOfBlocks) }")
                        
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
        
        let param = "''[]'',  ''{\(self.outputs)}'', 0, true"
        
        if isUsingSSH {
            
            executeNodeCommandSsh(method: BTC_CLI_COMMAND.createrawtransaction,
                                  param: param)
            
        } else {
            
            executeNodeCommandTor(method: BTC_CLI_COMMAND.createrawtransaction,
                                  param: param)
            
        }
        
    }
    
    func createBatchRawTransactionFromColdWallet(completion: @escaping () -> Void) {
        
        func executeNodeCommandSsh(method: BTC_CLI_COMMAND, param: String) {
            
            func getResult() {
                
                if !makeSSHCall.errorBool {
                    
                    switch method {
                        
                    case BTC_CLI_COMMAND.fundrawtransaction:
                        
                        let result = makeSSHCall.dictToReturn
                        unsignedRawTx = result["hex"] as! String
                        completion()
                        
                        
                    case BTC_CLI_COMMAND.createrawtransaction:
                        
                        let unsignedRawTx = makeSSHCall.stringToReturn
                        
                        executeNodeCommandSsh(method: BTC_CLI_COMMAND.fundrawtransaction,
                                              param: "\"\(unsignedRawTx)\", { \"includeWatching\":true, \"replaceable\": true, \"conf_target\": \(numberOfBlocks) }")
                        
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
                        
                    case BTC_CLI_COMMAND.fundrawtransaction:
                        
                        let result = torRPC.dictToReturn
                        unsignedRawTx = result["hex"] as! String
                        completion()
                        
                        
                    case BTC_CLI_COMMAND.createrawtransaction:
                        
                        let unsignedRawTx = torRPC.stringToReturn
                        
                        executeNodeCommandTor(method: BTC_CLI_COMMAND.fundrawtransaction,
                                              param: "\"\(unsignedRawTx)\", { \"includeWatching\":true, \"replaceable\": true, \"conf_target\": \(numberOfBlocks) }")
                        
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
        
        let param = "''[]'',  ''{\(self.outputs)}'', 0, true"
        
        if isUsingSSH {
            
            executeNodeCommandSsh(method: BTC_CLI_COMMAND.createrawtransaction,
                                  param: param)
            
        } else {
            
            executeNodeCommandTor(method: BTC_CLI_COMMAND.createrawtransaction,
                                  param: param)
            
        }
        
    }
    
}
