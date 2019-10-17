//
//  Reducer.swift
//  BitSense
//
//  Created by Peter on 20/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class Reducer {
    
    let isUsingSSH = IsUsingSSH.sharedInstance
    let ssh = SSHService.sharedInstance
    let makeSSHCall = SSHelper.sharedInstance
    let torRPC = MakeRPCCall.sharedInstance
    var dictToReturn = NSDictionary()
    var doubleToReturn = Double()
    var arrayToReturn = NSArray()
    var stringToReturn = String()
    var boolToReturn = Bool()
    var errorBool = Bool()
    var errorDescription = ""
    
    var method = ""
    
    func makeCommand(command: BTC_CLI_COMMAND, param: Any, completion: @escaping () -> Void) {
        
        method = command.rawValue
        
        func parseResponse(response: Any) {
            
            if let str = response as? String {
                
                self.stringToReturn = str
                completion()
                
            } else if let doub = response as? Double {
                
                self.doubleToReturn = doub
                completion()
                
            } else if let arr = response as? NSArray {
                
                self.arrayToReturn = arr
                completion()
                
            } else if let dic = response as? NSDictionary {
                
                self.dictToReturn = dic
                completion()
                
            } else {
                
                if command == BTC_CLI_COMMAND.unloadwallet {
                    
                    self.stringToReturn = "Wallet unloaded"
                    completion()
                    
                } else if command == BTC_CLI_COMMAND.importprivkey {
                    
                    self.stringToReturn = "Imported key success"
                    completion()
                    
                } else if command == BTC_CLI_COMMAND.walletpassphrase {
                    
                    self.stringToReturn = "Wallet decrypted"
                    completion()
                    
                } else if command == BTC_CLI_COMMAND.walletpassphrasechange {
                    
                    self.stringToReturn = "Passphrase updated"
                    completion()
                    
                } else if command == BTC_CLI_COMMAND.encryptwallet || command == BTC_CLI_COMMAND.walletlock {
                    
                    self.stringToReturn = "Wallet encrypted"
                    completion()
                    
                }
                
            }
            
        }
        
        func torCommand() {
            
            print("tor")
            
            func getResult() {
                
                if !torRPC.errorBool {
                    
                    //let response = torRPC
                    let response = torRPC.objectToReturn
                    parseResponse(response: response as Any)
                    
                } else {
                    
                    errorBool = true
                    errorDescription = torRPC.errorDescription
                    completion()
                    
                }
                
            }
            
            if TorClient.sharedInstance.isOperational {
                
                torRPC.executeRPCCommand(method: command,
                                         param: param,
                                         completion: getResult)
                
            } else {
                
                errorBool = true
                errorDescription = "tor not connected"
                
            }
            
        }
        
        func sshCommand() {
            
            print("ssh")
            
            func getResult() {
                
                if !makeSSHCall.errorBool {
                    
                    let response = makeSSHCall.objectToReturn
                    parseResponse(response: response as Any)
                    
                } else {
                    
                    errorBool = true
                    errorDescription = makeSSHCall.errorDescription
                    completion()
                    
                }
                
            }
            
            if ssh.session != nil && ssh.session.isConnected && ssh.session.isAuthorized {
                
                makeSSHCall.executeSSHCommand(ssh: ssh,
                                              method: command,
                                              param: param,
                                              completion: getResult)
                
            } else {
                
                errorBool = true
                errorDescription = "ssh is not connected"
                completion()
                
            }
            
        }
        
        if !isUsingSSH {
            
            torRPC.errorBool = false
            torRPC.errorDescription = ""
            torCommand()
            
        } else {
            
            sshCommand()
            
        }
        
    }
    
}
