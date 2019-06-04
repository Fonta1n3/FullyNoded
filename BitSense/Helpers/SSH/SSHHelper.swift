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
    var errorBool = Bool()
    var errorDescription = String()
    
    func executeSSHCommand(ssh: SSHService, method: BTC_CLI_COMMAND, param: Any, completion: @escaping () -> Void) {
        
        ssh.execute(command: method, params: param, response: { (result, error) in
            
            if error != nil {
                
                self.errorBool = true
                
                if error != "" {
                    
                    self.errorDescription = error!
                    
                } else {
                    
                    self.errorDescription = "SSH Error with commands \(method)"
                    
                }
                
                completion()
                
            } else {
                
                self.errorBool = false
                
                if let dict = result as? NSDictionary {
                    
                    self.dictToReturn = dict
                    completion()
                    
                } else if let str = result as? String {
                    
                    self.stringToReturn = str
                    completion()
                    
                } else if let doub = result as? Double {
                    
                    self.doubleToReturn = doub
                    completion()
                    
                } else if let arr = result as? NSArray {
                    
                    self.arrayToReturn = arr
                    completion()
                    
                }
                
            }
            
        })
        
    }
    
}
