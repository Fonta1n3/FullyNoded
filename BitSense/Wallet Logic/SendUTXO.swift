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
    var ssh:SSHService!
    var inputs = ""
    var address = ""
    var amount = Double()
    var signedRawTx = ""
    var errorBool = Bool()
    var errorDescription = ""
    var inputArray = [Any]()
    
    func createRawTransaction(completion: @escaping () -> Void) {
        
        self.inputs = self.inputArray.description
        self.inputs = self.inputs.replacingOccurrences(of: "[\"", with: "[")
        self.inputs = self.inputs.replacingOccurrences(of: "\"]", with: "]")
        self.inputs = self.inputs.replacingOccurrences(of: "\"{", with: "{")
        self.inputs = self.inputs.replacingOccurrences(of: "}\"", with: "}")
        self.inputs = self.inputs.replacingOccurrences(of: "\\", with: "")
        
        func executeNodeCommandSsh(method: BTC_CLI_COMMAND, param: String) {
            
            func getResult() {
                
                if !makeSSHCall.errorBool {
                    
                    switch method {
                        
                    case BTC_CLI_COMMAND.signrawtransactionwithwallet:
                        
                        let result = makeSSHCall.dictToReturn
                        let hex = result["hex"] as! String
                        self.signedRawTx = hex
                        completion()
                        
                    case BTC_CLI_COMMAND.createrawtransaction:
                        
                        let unsignedRawTx = makeSSHCall.stringToReturn
                        executeNodeCommandSsh(method: BTC_CLI_COMMAND.signrawtransactionwithwallet,
                                                   param: "\"\(unsignedRawTx)\"")
                        
                    default:
                        
                        break
                        
                    }
                    
                } else {
                   
                    self.errorBool = self.makeSSHCall.errorBool
                    self.errorDescription = self.makeSSHCall.errorDescription
                    completion()
                    
                }
                
            }
            
            if ssh.session.isConnected {
                
                makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                              method: method,
                                              param: param,
                                              completion: getResult)
                
            } else {
                
                errorBool = true
                errorDescription = "Not connected"
                completion()
                
            }
            
        }
        
        let receiver = "\"\(self.address)\":\(self.amount)"
        var param = "''\(self.inputs)'', ''{\(receiver)}''"
        param = param.replacingOccurrences(of: "\"{", with: "{")
        param = param.replacingOccurrences(of: "}\"", with: "}")
        
        executeNodeCommandSsh(method: BTC_CLI_COMMAND.createrawtransaction,
                              param: param)
        
    }
    
}
