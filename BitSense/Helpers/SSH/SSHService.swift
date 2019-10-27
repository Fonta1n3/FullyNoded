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
    var isConnected = false
    
    private init() {}
    
    func connect(success: @escaping((success:Bool, error:String?)) -> ()) {
        
        var port = ""
        var user = ""
        var host = ""
        var password = ""
        var privKey = ""
        var pubKey = ""
        
        let node = NodeStruct(dictionary: activeNode)
        
        if aes.decryptKey(keyToDecrypt: node.port) != "" {
            
            port = aes.decryptKey(keyToDecrypt: node.port)
            
        }
        
        if aes.decryptKey(keyToDecrypt: node.username) != "" {
            
            user = aes.decryptKey(keyToDecrypt: node.username)
            
        }
        
        if aes.decryptKey(keyToDecrypt: node.ip) != "" {
            
            host = aes.decryptKey(keyToDecrypt: node.ip)
            
        }
        
        
        if aes.decryptKey(keyToDecrypt: node.password) != "" {
            
            password = aes.decryptKey(keyToDecrypt: node.password)
            
        }
        
        if aes.decryptKey(keyToDecrypt: node.privateKey) != "" {
                
            privKey = aes.decryptKey(keyToDecrypt: node.privateKey)
                
        }
            
        if aes.decryptKey(keyToDecrypt: node.publicKey) != "" {
                
                pubKey = aes.decryptKey(keyToDecrypt: node.publicKey)
                
        }
                    
        guard user != "", host != "", port != "", password != "" else {
            
            success((success:false,
                     error:"incomplete ssh credentials"))
            
            return
            
        }
        
        var authWithPrivKey = false
        
        if pubKey != "" {
            
            authWithPrivKey = true
            
        }
        
        if let prt = Int(port) {
            
            let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
            
            queue.async {
                
                self.session = NMSSHSession.connect(toHost: host,
                                                    port: prt,
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
            
        } else {
            
            success((success:false,
                     error:"invalid ssh port"))
            
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
            
            let node = NodeStruct(dictionary: activeNode)
            let encuser = node.rpcuser
            let encpass = node.rpcpassword
            let encport = node.rpcport
            rpcuser = aes.decryptKey(keyToDecrypt: encuser)
            rpcpassword = aes.decryptKey(keyToDecrypt: encpass)
            rpcport = aes.decryptKey(keyToDecrypt: encport)
            
            guard rpcuser != "", rpcpassword != "", rpcport != "" else {
                
                response((dictionary:nil,
                          error:"incomplete rpc credentials"))
                
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
    
    func clearHistory(response: @escaping (Bool) -> Void) {
        
        if !commandExecuting {
            
            var error: NSError?
            let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
            
            let cmd = "history -c"
            
            queue.async {
                
                if let _ = self.session?.channel.execute(cmd, error: &error) {
                    
                    if error != nil {
                        
                        print("error clearing history")
                        response((false))
                        
                    } else {
                        
                        response((true))
                        
                    }
                    
                } else {
                    
                    response((false))
                    
                }
                
            }
            
        } else {
            
            response((false))
            
        }
        
    }
    
    
    
    func getKeys(response: @escaping(String) -> ()) {
        
        var error: NSError?
        let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
        let cmd = "python3 createKeys.py"
        
        if !isConnected {
            
            queue.async {
                
                self.session = NMSSHSession.connect(toHost: "35.239.123.188",
                                                    port: 22,
                                                    withUsername: "fontainedenton")
                                
                if self.session.isConnected == true {
                
                    self.session.authenticate(byPassword: "V4RM73Q6C3MPTKMAI4VMWNBEVJ6YCOEBPY75HFKSA5CZP2YMB5JQ")
                    
                    if self.session.isAuthorized {
                        
                        self.isConnected = true
                        
                        if let responseString = self.session?.channel.execute(cmd, error: &error) {
                            
                            if error != nil {
                                
                                print("error clearing history")
                                response(("error"))
                                
                            } else {
                                
                                response((responseString))
                                print("responsestring = \(responseString)")
                                
                            }
                            
                        } else {
                            
                            response(("error"))
                            
                        }
                        
                    }
                    
                }
                
            }
            
        } else {
            
            if let responseString = self.session?.channel.execute(cmd, error: &error) {
                
                if error != nil {
                    
                    print("error clearing history")
                    response(("error"))
                    
                } else {
                    
                    response((responseString))
                    print("responsestring = \(responseString)")
                    
                }
                
            } else {
                
                response(("error"))
                
            }
            
        }
                
    }
    
}
