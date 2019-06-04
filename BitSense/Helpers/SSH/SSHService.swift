//
//  SSHService.swift
//  BitSense
//
//  Created by Peter on 10/12/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import Foundation
import NMSSH

class SSHService {
    
    var session:NMSSHSession!
    static let sharedInstance = SSHService()
    
    private init() {}
    
    func connect(activeNode: [String:Any], success: @escaping((success:Bool, error:String?)) -> ()) {
        
        let aes = AESService()
        
        var port = "22"
        var user = "user"
        var host = "host"
        var password = "password"
        
        if let portCheck = aes.decryptKey(keyToDecrypt: activeNode["port"] as! String) as? String {
            
            port = portCheck
            
        }
        
        if let userCheck = aes.decryptKey(keyToDecrypt: activeNode["username"] as! String) as? String {
            
            user = userCheck
            
        }
        
        if let hostCheck = aes.decryptKey(keyToDecrypt: activeNode["ip"] as! String) as? String {
            
            host = hostCheck
            
        }
        
        if let passwordCheck = aes.decryptKey(keyToDecrypt: activeNode["password"] as! String) as? String {
            
            password = passwordCheck
            
        }
        
        guard user != "", host != "", password != "" else {
            
            success((success:false, error:"Incomplete Credentials"))
            return
            
        }
        
        var portInt = Int()
        
        if port != "" {
            
            portInt = Int(port)!
            
            let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
            queue.async {
            
            self.session = NMSSHSession.connect(toHost: host, port: portInt, withUsername: user)
            
            if self.session.isConnected == true {
                
                self.session.authenticate(byPassword: password)
                
                if self.session.isAuthorized {
                    
                    success((success:true, error:nil))
                    print("success")
                    
                } else {
                    
                    success((success:false, error:"\(String(describing: self.session.lastError!))"))
                    print("fail")
                    print("\(String(describing: self.session?.lastError))")
                    
                 }
                
            } else {
                
                print("Session not connected")
                success((success:false, error:"Unable to connect"))
                
            }
                
            }
            
        }
        
    }
    
    func disconnect() {
        
        session?.disconnect()
        
    }
    
    func execute(command: BTC_CLI_COMMAND, params: Any, response: @escaping((dictionary:Any?, error:String?)) -> ()) {
        
        var error: NSError?
        var path = "bitcoin-cli"
        
        if UserDefaults.standard.object(forKey: "path") != nil {
            
            path = UserDefaults.standard.object(forKey: "path") as! String
            
        }
        
        let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
        queue.async {
            
            if let responseString = self.session?.channel.execute("\(path) \(command.rawValue) \(params)", error: &error) {
                
                print("responseString = \(String(describing: responseString))")
                
                if error != nil {
                    
                    print("error = \(error!.localizedDescription)")
                    response((dictionary:nil, error:error!.localizedDescription))
                    
                } else {
                    
                    if command == BTC_CLI_COMMAND.getnewaddress || command == BTC_CLI_COMMAND.getrawchangeaddress || command == BTC_CLI_COMMAND.createrawtransaction {
                        
                        if responseString.hasSuffix("\n") {
                            
                            let address = responseString.replacingOccurrences(of: "\n", with: "")
                            
                            response((dictionary: address,error: nil))
                            
                        } else {
                            
                            response((dictionary:responseString,error:nil))
                            
                        }
                        
                    } else {
                        
                        guard let responseData = responseString.data(using: .utf8) else { return }
                        
                        do {
                            
                            let json = try JSONSerialization.jsonObject(with: responseData, options: [.allowFragments]) as Any
                            
                            response((dictionary:json, error:nil))
                            
                        } catch {
                            
                            response((dictionary:nil, error:"JSON ERROR: \(error)"))
                            print("error = \(error)")
                            
                        }
                        
                    }
                    
                }
                
            }
            
        }
            
     }
    
    
    
    /*func executeStringResponse(command: BTC_CLI_COMMAND, params: String, response: @escaping((string:String?, error:String?)) -> ()) {
        
        let error = NSErrorPointer.none
        
        if let responseString = session?.channel.execute("/usr/local/bin/bitcoin-cli \(command.rawValue) \(params)",
            error: error ?? nil).replacingOccurrences(of: "\n", with: "") {
            
            if error != nil {
                
                print("error getting response string")
                response((string: "", error:"ERROR: \(error!.debugDescription)"))
                
            } else {
                
                print("responseString = \(String(describing: responseString))")
                response((string: responseString, error:nil))
                
            }
            
        }
        
    }*/
    
}
