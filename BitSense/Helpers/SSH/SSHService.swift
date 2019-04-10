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
    
    var user:String!
    var host:String!
    var port:String!
    var password:String!
    var session:NMSSHSession!
    static let sharedInstance = SSHService()
    
    private init() {
        
        print("SSHService")
        
    }
    
    func connect(success: @escaping((success:Bool, error:String?)) -> ()) {
        
        guard user != nil, host != nil, password != nil else {
            
            success((success:false, error:"Incomplete Credentials"))
            return
            
        }
        
        var portInt = Int()
        
        if port != "" {
            
            portInt = Int(port!)!
            
            print("host = \(String(describing: host)), port = \(String(describing: port)), user = \(String(describing: user))")
            
            session = NMSSHSession.connect(toHost: host!, port: portInt, withUsername: user!)
            
            if session.isConnected == true {
                
                session.authenticate(byPassword: password!)
                
                if session.isAuthorized == true {
                    
                    success((success:true, error:nil))
                    print("success")
                    
                } else {
                    
                    success((success:false, error:"\(String(describing: session.lastError!))"))
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
                        
                let json = try JSONSerialization.jsonObject(with: responseData, options: []) as Any
                            
                response((dictionary:json, error:nil))
                            
                
            } catch {
                        
                response((dictionary:nil, error:"JSON ERROR: \(error)"))
                        
            }
                    
        }
                
     }
    
    func executeStringResponse(command: BTC_CLI_COMMAND, params: String, response: @escaping((string:String?, error:String?)) -> ()) {
        
        let error = NSErrorPointer.none
        
        if let responseString = session?.channel.execute("bitcoin-cli \(command.rawValue) \(params)", error: error ?? nil).replacingOccurrences(of: "\n", with: "") {
            
            if error != nil {
                
                print("error getting response string")
                response((string: "", error:"ERROR: \(error!.debugDescription)"))
                
            } else {
                
                print("responseString = \(String(describing: responseString))")
                response((string: responseString, error:nil))
                
            }
            
        }
        
    }
    
}
