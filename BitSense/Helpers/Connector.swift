//
//  Connector.swift
//  BitSense
//
//  Created by Peter on 24/08/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class Connector {
    
    var torClient:TorClient!
    var torRPC:MakeRPCCall!
    var torConnected:Bool!
    
    var ssh:SSHService!
    var makeSSHCall:SSHelper!
    var sshConnected:Bool!
    
    var activeNode:[String:Any]!
    
    var errorBool:Bool!
    var errorDescription:String!
    
    func connectTor(completion: @escaping () -> Void) {
        
        self.torClient = TorClient.sharedInstance
        
        func completed() {
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                
                if self.torClient.isOperational {
                    print("Tor connected")
                    
                    self.torRPC = MakeRPCCall.sharedInstance
                    self.torConnected = true
                    completion()
                    
                } else {
                    
                    print("error connecting tor")
                    self.torConnected = false
                    completion()
                    
                }
                
            })
            
        }
        
        if self.torClient.isRefreshing {
            
            self.torClient.restart(completion: completed)
            
        } else {
            
            self.torClient.start(completion: completed)
            
        }
        
    }
    
    func connectSSH(completion: @escaping () -> Void) {
        
        self.ssh = SSHService.sharedInstance
        self.ssh.activeNode = self.activeNode
        self.ssh.commandExecuting = false
        
        self.ssh.connect() { (success, error) in
            
            if success {
                
                print("ssh connected succesfully")
                self.makeSSHCall = SSHelper.sharedInstance
                self.sshConnected = true
                self.errorBool = false
                completion()
                
            } else {
                
                print("ssh connection failed")
                
                if error != nil {
                    
                    if error == "" {
                        
                        self.errorDescription = "Unable to authenticate SSH"
                        
                    } else {
                        
                        self.errorDescription = error!
                        
                    }
                    
                } else {
                    
                    self.errorDescription = "Unable to connect"
                    
                }
                
                self.errorBool = true
                self.sshConnected = false
                completion()
                
            }
            
        }
        
    }
    
}
