//
//  NodeStruct.swift
//  BitSense
//
//  Created by Peter on 18/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation


public struct NodeStruct: CustomStringConvertible {
    
    let id:String
    let label:String
    let isActive:Bool
    let isDefault:Bool
    let ip:String
    let onionAddress:String
    let password:String
    let port:String
    let privateKey:String
    let publicKey:String
    let rpcpassword:String
    let rpcport:String
    let rpcuser:String
    let username:String
    let usingSSH:Bool
    let usingTor:Bool
    let authKey:String
    
    init(dictionary: [String: Any]) {
        
        self.id = dictionary["id"] as? String ?? ""
        self.label = dictionary["label"] as? String ?? ""
        self.isActive = dictionary["isActive"] as? Bool ?? false
        self.isDefault = dictionary["isDefault"] as? Bool ?? false
        self.ip = dictionary["ip"] as? String ?? ""
        self.onionAddress = dictionary["onionAddress"] as? String ?? ""
        self.password = dictionary["password"] as? String ?? ""
        self.port = dictionary["port"] as? String ?? ""
        self.privateKey = dictionary["privateKey"] as? String ?? ""
        self.publicKey = dictionary["publicKey"] as? String ?? ""
        self.rpcpassword = dictionary["rpcpassword"] as? String ?? ""
        self.rpcport = dictionary["rpcport"] as? String ?? ""
        self.rpcuser = dictionary["rpcuser"] as? String ?? ""
        self.username = dictionary["username"] as? String ?? ""
        self.usingSSH = dictionary["usingSSH"] as? Bool ?? false
        self.usingTor = dictionary["usingTor"] as? Bool ?? false
        self.authKey = dictionary["authKey"] as? String ?? ""
        
    }
    
    public var description: String {
        return ""
    }
    
}

