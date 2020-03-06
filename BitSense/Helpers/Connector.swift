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
    
    var activeNode:[String:Any]!
    
    var errorBool:Bool!
    var errorDescription:String!
    
    func connectTor(completion: @escaping () -> Void) {
        print("connect tor")
        
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
            
            //self.torClient.restart(completion: completed)
            
        } else {
            
            self.torClient.start(completion: completed)
            
        }
        
    }
    
}
