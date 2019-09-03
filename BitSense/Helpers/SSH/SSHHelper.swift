//
//  SSHHelper.swift
//  BitSense
//
//  Created by Peter on 13/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class SSHelper {
    
    static let sharedInstance = SSHelper()
    var dictToReturn = NSDictionary()
    var doubleToReturn = Double()
    var arrayToReturn = NSArray()
    var stringToReturn = String()
    var boolToReturn = Bool()
    var errorBool = Bool()
    var errorDescription = String()
    
    func executeSSHCommand(ssh: SSHService, method: BTC_CLI_COMMAND, param: Any, completion: @escaping () -> Void) {
        
        ssh.execute(command: method, params: param, response: { (result, error) in
            
            if error != nil {
                
                self.errorBool = true
                
                if error != "" {
                    
                    if method == BTC_CLI_COMMAND.getblockchaininfo {
                        
                        self.errorDescription = "Looks like your RPC credentials might be incorrect"
                        
                    } else {
                        
                        self.errorDescription = error!
                        
                    }
                    
                } else {
                    
                    self.errorDescription = "SSH Error with commands \(method)"
                    
                }
                
                completion()
                
            } else {
                
                self.errorBool = false
                
                if let dict = result as? NSDictionary {
                    
                    if let err = dict["error"] as? NSDictionary {
                        
                        let errorMessage = err["message"] as! String
                        self.errorBool = true
                        self.errorDescription = "Bitcoin Core error:" + " " + errorMessage
                        completion()
                        
                    } else {
                        
                        if let str = dict["result"] as? String {
                            
                            self.stringToReturn = str
                            completion()
                            
                        } else if let doub = dict["result"] as? Double {
                            
                            self.doubleToReturn = doub
                            completion()
                            
                        } else if let arr = dict["result"] as? NSArray {
                            
                            self.arrayToReturn = arr
                            completion()
                            
                        } else if let dic = dict["result"] as? NSDictionary {
                            
                            self.dictToReturn = dic
                            completion()
                        
                        } else {
                            
                            if method == BTC_CLI_COMMAND.unloadwallet {
                                
                                self.stringToReturn = "Wallet unloaded"
                                completion()
                                
                            } else if method == BTC_CLI_COMMAND.importprivkey {
                                
                                self.stringToReturn = "Imported key success"
                                completion()
                                
                            }
                            
                        }
                        
                    }
                    
                }
                
            }
            
        })
        
    }
    
}
