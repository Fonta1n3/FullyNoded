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
    var errorBool = Bool()
    var errorDescription = String()
    var objectToReturn:Any!
    
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
                        
                        self.objectToReturn = dict["result"]
                        completion()
                        
                    }
                    
                }
                
            }
            
        })
        
    }
    
}
