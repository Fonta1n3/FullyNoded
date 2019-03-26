//
//  SSHService.swift
//  BitSense
//
//  Created by Peter on 10/12/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import Foundation
import NMSSH
import AES256CBC
import SwiftKeychainWrapper

class SSHService {
    
    let userDefaults = UserDefaults.standard
    var user:String?
    var host:String?
    var port:String?
    var password:String?
    var session: NMSSHSession?
    static let sharedInstance = SSHService()
    
    private init() {
        
        print("SSHService")
        
       func decryptSSHKey(keyToDecrypt: String) -> String {
            print("decryptSSHKey")
            let pw = KeychainWrapper.standard.string(forKey: "AESPassword")!
            let decryptedkey = AES256CBC.decryptString(keyToDecrypt, password: pw)!
            return decryptedkey
        }
        
        func decryptKey(keyToDecrypt:String) -> String {
            print("decryptKey")
            let pw = KeychainWrapper.standard.string(forKey: "AESPassword")!
            let decryptedKey = AES256CBC.decryptString(keyToDecrypt, password: pw)!
            return decryptedKey
        }
        
        if UserDefaults.standard.string(forKey: "sshPassword") != nil {
            
            user = decryptKey(keyToDecrypt: UserDefaults.standard.string(forKey: "NodeUsername")!)
            host = decryptKey(keyToDecrypt: UserDefaults.standard.string(forKey: "NodeIPAddress")!)
            password = decryptSSHKey(keyToDecrypt: UserDefaults.standard.string(forKey: "sshPassword")!)
            port = decryptKey(keyToDecrypt: UserDefaults.standard.string(forKey: "NodePort")!)
            
            print("user = \(String(describing: user))")
            print("host = \(String(describing: host))")
            print("password = \(String(describing: password))")
            print("port = \(String(describing: port))")
            
        } else {
            
            user = ""
            host = ""
            password = ""
            port = ""
            
        }
        
    }
    
    func connect(success: @escaping((success:Bool, error:String?)) -> ()) {
        
        guard user != nil, host != nil, password != nil else {
            
            success((success:false, error:"Error"))
            return
            
        }
        
        var portInt = Int()
        
        if port != "" {
            
            portInt = Int(port!)!
            
            session = NMSSHSession.connect(toHost: host!, port: portInt, withUsername: user!)
            
            if session?.isConnected == true {
                
                session?.authenticate(byPassword: password!)
                
                if session?.isAuthorized == true {
                    
                    success((success:true, error:nil))
                    print("success")
                    
                } else {
                    
                    success((success:false, error:"Error"))
                    print("fail")
                    print("\(String(describing: session?.lastError))")
                    
                 }
                
            } else {
                
                print("Session not connected")
                success((success:false, error:"Unable to connect via SSH, please make sure your firewall allows SSH connections and ensure you input the correct port."))
                
            }
            
        }
        
        
    }
    
    func disconnect() {
        
        session?.disconnect()
        
    }
    
    func execute(command: BTC_CLI_COMMAND, params: String, response: @escaping((dictionary:Any?, error:String?)) -> ()) {
        
        let error = NSErrorPointer.none
            
        if let responseString = session?.channel.execute("bitcoin-cli \(command.rawValue) \(params)", error: error ?? nil) {
                    
            print("responseString = \(String(describing: responseString))")
                    
            guard let responseData = responseString.data(using: .utf8) else { return }
                    
            do {
                        
                if let json = try JSONSerialization.jsonObject(with: responseData, options: []) as? Any {
                            
                    response((dictionary:json, error:nil))
                            
                }
                        
            } catch {
                        
                response((dictionary:nil, error:"JSON ERROR: \(error)"))
                        
            }
                    
        }
                
     }
    
    func executeStringResponse(command: BTC_CLI_COMMAND, params: String, response: @escaping((string:String?, error:String?)) -> ()) {
        var error: NSErrorPointer?
        do {
            let responseString:String? = try session?.channel.execute("bitcoin-cli \(command.rawValue) \(params)", error: error ?? nil).replacingOccurrences(of: "\n", with: "")
            print("responseString = \(String(describing: responseString))")
            response((string: responseString, error:nil))
        } catch {
            print("error getting response string")
            response((string: "", error:"ERROR: \(error)"))
        }
    }
    
}
