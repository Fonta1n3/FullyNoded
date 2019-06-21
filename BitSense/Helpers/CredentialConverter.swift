//
//  CredentialConverter.swift
//  BitSense
//
//  Created by Peter on 04/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation
import UIKit

class CredentialConverter {
    
    func convertCredentials(vc: UIViewController) {
        
        let cd = CoreDataService()
        var credentialsExist = false
        let userDefaults = UserDefaults.standard
        var credentials = [String:Any]()
        var username = String()
        var password = String()
        var port = String()
        var ip = String()
        var sshPassword = String()
        
        credentials["id"] = randomString(length: 7)
        
        if userDefaults.string(forKey: "NodeUsername") != nil {
            
            username = userDefaults.string(forKey: "NodeUsername")!
            credentials["username"] = username
            credentialsExist = true
            
        }
        
        if userDefaults.string(forKey: "NodeIPAddress") != nil {
            
            ip = userDefaults.string(forKey: "NodeIPAddress")!
            credentials["ip"] = ip
            credentialsExist = true
            
        }
        
        if userDefaults.string(forKey: "NodePort") != nil {
            
            port = userDefaults.string(forKey: "NodePort")!
            credentials["port"] = port
            credentialsExist = true
            
        }
        
        if userDefaults.string(forKey: "NodePassword") != nil {
            
            sshPassword = userDefaults.string(forKey: "NodePassword")!
            credentials["password"] = sshPassword
            credentialsExist = true
            
        }
        
        if userDefaults.string(forKey: "sshPassword") != nil {
            
            sshPassword = userDefaults.string(forKey: "sshPassword")!
            credentials["password"] = sshPassword
            credentialsExist = true
            
        }
        
        if credentialsExist {
            
            credentials["isActive"] = true
            credentials["label"] = "Your node"
            
            let success = cd.saveCredentialsToCoreData(vc: vc, credentials: credentials)
            
            if success {
                
                print("converted node saved")
                
                userDefaults.removeObject(forKey: "sshPassword")
                userDefaults.removeObject(forKey: "NodePassword")
                userDefaults.removeObject(forKey: "NodePort")
                userDefaults.removeObject(forKey: "NodeIPAddress")
                userDefaults.removeObject(forKey: "NodeUsername")
                
                userDefaults.set(true, forKey: "hasConverted")
                
            } else {
                
                print("failed to save default node")
                
            }
            
        }
            
        let aes = AESService()
        
        func saveDefaultNode() {
            
            var defaultNode = [String:Any]()
            let prt = aes.encryptKey(keyToEncrypt: "22")
            let host = aes.encryptKey(keyToEncrypt: "someIP")
            let un = aes.encryptKey(keyToEncrypt: "user")
            let pw = aes.encryptKey(keyToEncrypt: "password")
            let path = aes.encryptKey(keyToEncrypt: "bitcoin-cli")
            let label = aes.encryptKey(keyToEncrypt: "Testing Node")
            defaultNode["port"] = prt
            defaultNode["ip"] = host
            defaultNode["username"] = un
            defaultNode["password"] = pw
            defaultNode["id"] = randomString(length: 7)
            defaultNode["path"] = path
            defaultNode["label"] = label
            
            if credentialsExist {
                
                defaultNode["isActive"] = false
                defaultNode["isDefault"] = false
                
            } else {
                
                defaultNode["isActive"] = true
                defaultNode["isDefault"] = true
                
            }
            
            let saveDef = cd.saveCredentialsToCoreData(vc: vc, credentials: defaultNode)
            
            if saveDef {
                
                print("default node saved")
                
                userDefaults.set(true, forKey: "hasConverted")
                
            } else {
                
                print("failed to save default node")
                
            }
            
        }
        
        saveDefaultNode()
        
    }
    
}
