//
//  GetHDMusigAddress.swift
//  BitSense
//
//  Created by Peter on 08/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class GetHDMusigAddress {
    
    var torClient:TorClient!
    var torRPC:MakeRPCCall!
    var ssh:SSHService!
    var makeSSHCall:SSHelper!
    
    let cd = CoreDataService()
    let aes = AESService()
    
    var errorBool = Bool()
    var errorDescription = ""
    
    var descriptor = ""
    var addressIndex = ""
    var label = ""
    
    var addressToReturn = ""
    
    var wallet = [String:Any]()
    
    func getHDMusigAddress(completion: @escaping () -> Void) {
        
        func executeNodeCommandSsh(method: BTC_CLI_COMMAND, param: String) {
            print("executeNodeCommandSsh getHDMusigAddress")
            
            func getResult() {
                
                if !makeSSHCall.errorBool {
                    
                    switch method {
                        
                    case BTC_CLI_COMMAND.deriveaddresses:
                        
                        let result = makeSSHCall.arrayToReturn
                        print("result = \(result)")
                        addressToReturn = result[0] as! String
                        completion()
                        
                    default:
                        
                        break
                        
                    }
                    
                } else {
                    
                    errorBool = true
                    errorDescription = self.makeSSHCall.errorDescription
                    completion()
                    
                }
                
            }
            
            if self.ssh != nil {
                
                if self.ssh.session.isConnected {
                    
                    makeSSHCall.executeSSHCommand(ssh: self.ssh,
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

        descriptor = aes.decryptKey(keyToDecrypt: wallet["descriptor"] as! String)
        let range = aes.decryptKey(keyToDecrypt: wallet["range"] as! String)
        label = aes.decryptKey(keyToDecrypt: wallet["label"] as! String)
        addressIndex = aes.decryptKey(keyToDecrypt: wallet["index"] as! String)
        
        print("descriptor = \(descriptor)")
        print("range = \(range)")
        print("label = \(label)")
        print("addressIndex = \(addressIndex)")
        
        let param = "\(descriptor), [\(addressIndex),\(addressIndex)]"
        
        //derive address
        executeNodeCommandSsh(method: BTC_CLI_COMMAND.deriveaddresses,
                              param: param)
        
    }
    
}
