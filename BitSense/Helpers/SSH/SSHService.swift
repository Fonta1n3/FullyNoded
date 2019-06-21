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
    var path = "bitcoin-cli"
    let aes = AESService()
    
    private init() {}
    
    func connect(activeNode: [String:Any], success: @escaping((success:Bool, error:String?)) -> ()) {
        
        var port = ""
        var user = ""
        var host = ""
        var password = ""
        
        if let pathCheck = activeNode["path"] as? String {
            
            if aes.decryptKey(keyToDecrypt: pathCheck) != "" {
                
                path = aes.decryptKey(keyToDecrypt: pathCheck)
                
            }
            
        }
        
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
                        
                        success((success:false, error:"\(String(describing: self.session.lastError!.localizedDescription))"))
                        print("fail")
                        print("\(String(describing: self.session?.lastError))")
                        
                    }
                    
                } else {
                    
                    print("Session not connected")
                    success((success:false, error:"Unable to connect to your node with SSH"))
                    
                }
                
            }
            
        }
        
    }
    
    func disconnect() {
        
        session?.disconnect()
        
    }
    
    func execute(command: BTC_CLI_COMMAND, params: Any, response: @escaping((dictionary:Any?, error:String?)) -> ()) {
        
        var commandToExecute = "\(self.path) \(command.rawValue) \(params)"
        
        if let walletName = UserDefaults.standard.object(forKey: "walletName") as? String {
            
            let b = isWalletRPC(command: command)
            
            if b {
                
                commandToExecute = "\(self.path) -rpcwallet=\(walletName) \(command.rawValue) \(params)"
                
            }
            
        }
            
        var error: NSError?
        
        let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
        
        queue.async {
            
            if let responseString = self.session?.channel.execute(commandToExecute, error: &error) {
                
                print("responseString = \(String(describing: responseString))")
                
                if responseString == "" && command == BTC_CLI_COMMAND.importprivkey || command == BTC_CLI_COMMAND.importaddress {
                    
                    response((dictionary:"Imported key success", error:nil))
                    
                } else if responseString == "" && command == BTC_CLI_COMMAND.unloadwallet {
                    
                    response((dictionary:"Wallet unloaded", error:nil))
                    
                } else {
                    
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
                                
                                response((dictionary:nil, error:"\(error.localizedDescription)"))
                                print("error = \(error)")
                                
                            }
                            
                        }
                        
                    }
                    
                }
                
            }
            
        }
            
     }
    
    func isWalletRPC(command: BTC_CLI_COMMAND) -> Bool {
        
        var boolToReturn = Bool()
        
        switch command {
            
        case BTC_CLI_COMMAND.listtransactions,
             BTC_CLI_COMMAND.getbalance,
             BTC_CLI_COMMAND.getunconfirmedbalance,
             BTC_CLI_COMMAND.getnewaddress,
             BTC_CLI_COMMAND.getwalletinfo,
             BTC_CLI_COMMAND.importmulti,
             BTC_CLI_COMMAND.rescanblockchain,
             BTC_CLI_COMMAND.fundrawtransaction,
             BTC_CLI_COMMAND.listunspent:
            
            boolToReturn = true
            
        default:
            
            boolToReturn = false
            
        }
        
        return boolToReturn
        
    }
    
}
