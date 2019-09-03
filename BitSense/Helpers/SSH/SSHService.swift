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
    let aes = AESService()
    var activeNode = [String:Any]()
    var commandExecuting = false
    
    private init() {}
    
    func connect(success: @escaping((success:Bool, error:String?)) -> ()) {
        
        var port = ""
        var user = ""
        var host = ""
        var password = ""
        var privKey = ""
        var pubKey = ""
        
        if let portCheck = activeNode["port"] as? String {
            
            if aes.decryptKey(keyToDecrypt: portCheck) != "" {
                
                port = aes.decryptKey(keyToDecrypt: portCheck)
                
            }
            
        }
        
        if let userCheck = activeNode["username"] as? String {
            
            if aes.decryptKey(keyToDecrypt: userCheck) != "" {
                
                user = aes.decryptKey(keyToDecrypt: userCheck)
                
            }
            
        }
        
        if let hostCheck = activeNode["ip"] as? String {
            
            if aes.decryptKey(keyToDecrypt: hostCheck) != "" {
                
                host = aes.decryptKey(keyToDecrypt: hostCheck)
                
            }
            
        }
        
        if let passwordCheck = activeNode["password"] as? String {
            
            if aes.decryptKey(keyToDecrypt: passwordCheck) != "" {
                
                password = aes.decryptKey(keyToDecrypt: passwordCheck)
                
            }
            
        }
        
        if let privKeyCheck = activeNode["privateKey"] as? String {
            
            if aes.decryptKey(keyToDecrypt: privKeyCheck) != "" {
                
                privKey = aes.decryptKey(keyToDecrypt: privKeyCheck)
                
            }
            
        }
        
        if let pubKeyCheck = activeNode["publicKey"] as? String {
            
            if aes.decryptKey(keyToDecrypt: pubKeyCheck) != "" {
                
                pubKey = aes.decryptKey(keyToDecrypt: pubKeyCheck)
                
            }
            
        }
        
        guard user != "", host != "", port != "" else {
            
            success((success:false, error:"Incomplete SSH Credentials"))
            return
            
        }
        
        var authWithPrivKey = false
        
        if pubKey != "" || privKey != "" {
            
            authWithPrivKey = true
            
        }
        
        var portInt = Int()
        portInt = Int(port)!
        
        let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
        
        queue.async {
            
            self.session = NMSSHSession.connect(toHost: host,
                                                port: portInt,
                                                withUsername: user)
            
            if self.session.isConnected == true {
                
                if !authWithPrivKey {
                    
                    self.session.authenticate(byPassword: password)
                    
                } else {
                    
                    self.session.authenticateBy(inMemoryPublicKey: pubKey,
                                                privateKey: privKey,
                                                andPassword: password)
                    
                }
                
                if self.session.isAuthorized {
                    
                    success((success:true,
                             error:nil))
                    
                } else {
                    
                    success((success:false,
                             error:"\(String(describing: self.session.lastError!.localizedDescription))"))
                    
                }
                
            } else {
                
                success((success:false,
                         error:"Unable to connect to your node with SSH"))
                
            }
            
        }
        
    }
    
    func disconnect() {
        
        session?.disconnect()
        
    }
    
    func execute(command: BTC_CLI_COMMAND, params: Any, response: @escaping((dictionary:Any?, error:String?)) -> ()) {
        
        if !commandExecuting {
            
            commandExecuting = true
            
            var rpcuser = ""
            var rpcpassword = ""
            var rpcport = ""
            
            if activeNode["rpcuser"] != nil {
                
                let enc = activeNode["rpcuser"] as! String
                rpcuser = aes.decryptKey(keyToDecrypt: enc)
                
            }
            
            if activeNode["rpcpassword"] != nil {
                
                let enc = activeNode["rpcpassword"] as! String
                rpcpassword = aes.decryptKey(keyToDecrypt: enc)
                
            }
            
            if activeNode["rpcport"] != nil {
                
                let enc = activeNode["rpcport"] as! String
                rpcport = aes.decryptKey(keyToDecrypt: enc)
                
            }
            
            guard rpcuser != "", rpcpassword != "", rpcport != "" else {
                
                response((dictionary:nil,
                          error:"Incomplete RPC Credentials"))
                
                commandExecuting = false
                
                return
                
            }
            
            let userDefaults = UserDefaults.standard
            
            var url = "http://\(rpcuser):\(rpcpassword)@127.0.0.1:\(rpcport)/"
            
            if userDefaults.object(forKey: "walletName") != nil {
                
                if let walletName = userDefaults.object(forKey: "walletName") as? String {
                    
                    let b = isWalletRPC(command: command)
                    
                    if b {
                        
                        url += "wallet/" + walletName
                        
                    }
                    
                }
                
            }
            
            let curlCommand = "curl --data-binary '{\"jsonrpc\": \"1.0\", \"id\":\"curltest\", \"method\": \"\(command)\", \"params\":[\(params)] }' -H 'content-type: text/plain;' \(url)"
            
            var error: NSError?
            
            let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
            
            queue.async {
                
                if let responseString = self.session?.channel.execute(curlCommand, error: &error) {
                    
                    if error != nil {
                        
                        if error!.localizedDescription == "Channel allocation error" {
                            
                            // connection timed out, reconnect automatically
                            self.connect(success: { (success, error2) in
                                
                                if error2 != nil {
                                    
                                    self.commandExecuting = false
                                    
                                    response((dictionary:nil,
                                              error:error2))
                                    
                                } else if success {
                                    
                                    self.commandExecuting = false
                                    
                                    self.execute(command: command,
                                                 params: params,
                                                 response: response)
                                    
                                }
                                
                            })
                            
                        } else {
                            
                            self.commandExecuting = false
                            
                            response((dictionary:nil,
                                      error:error!.localizedDescription))
                            
                        }
                        
                    } else {
                        
                        guard let responseData = responseString.data(using: .utf8) else { return }
                        
                        do {
                            
                            let json = try JSONSerialization.jsonObject(with: responseData, options: [.allowFragments]) as Any
                            
                            self.commandExecuting = false
                            
                            response((dictionary:json,
                                      error:nil))
                            
                        } catch {
                            
                            self.commandExecuting = false
                            
                            response((dictionary:nil,
                                      error:"\(error.localizedDescription)"))
                            
                        }
                        
                    }
                    
                }
                
            }
            
        } else {
            
            response((dictionary:nil,
                      error:"Node is busy, try again in a moment"))
            
        }
        
    }
    
}
