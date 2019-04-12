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
    
    static let sharedInstance = CredentialConverter()
    
    func convertCredentials(vc: UIViewController) {
        
        let cd = CoreDataService.sharedInstance
        var credentialsExist = Bool()
        let userDefaults = UserDefaults.standard
        var credentials = [String:Any]()
        var username = String()
        var password = String()
        var port = String()
        var ip = String()
        var sshPassword = String()
        var isRPC = Bool()
        var isSSH = Bool()
        
        credentials["id"] = randomString(length: 7)
        
        if userDefaults.string(forKey: "NodeUsername") != nil {
            
            username = userDefaults.string(forKey: "NodeUsername")!
            credentials["username"] = username
            credentialsExist = true
            
        } else {
            
            credentialsExist = false
            
        }
        
        if userDefaults.string(forKey: "NodeIPAddress") != nil {
            
            ip = userDefaults.string(forKey: "NodeIPAddress")!
            credentials["ip"] = ip
            credentialsExist = true
            
        } else {
            
            credentialsExist = false
            
        }
        
        if userDefaults.string(forKey: "NodePort") != nil {
            
            port = userDefaults.string(forKey: "NodePort")!
            credentials["port"] = port
            credentialsExist = true
            
        } else {
            
            credentialsExist = false
            
        }
        
        if userDefaults.string(forKey: "sshPassword") != nil {
            
            isSSH = true
            isRPC = false
            sshPassword = userDefaults.string(forKey: "sshPassword")!
            credentials["password"] = sshPassword
            credentialsExist = true
            
        } else {
            
            isSSH = false
            isRPC = true
            
            if userDefaults.string(forKey: "NodePassword") != nil {
                
                password = userDefaults.string(forKey: "NodePassword")!
                credentials["password"] = password
                credentialsExist = true
                
            } else {
                
                credentialsExist = false
                
            }
            
        }
        
        credentials["isRPC"] = isRPC
        credentials["isSSH"] = isSSH
        credentials["isActive"] = true
        
        let aes = AESService.sharedInstance
        
        func saveDefaultNode() {
            
            var defaultNode = [String:Any]()
            let prt = aes.encryptKey(keyToEncrypt: "18332")
            let host = aes.encryptKey(keyToEncrypt: "46.101.239.249")
            let un = aes.encryptKey(keyToEncrypt: "bitcoin")
            let pw = aes.encryptKey(keyToEncrypt: "password")
            defaultNode["port"] = prt
            defaultNode["ip"] = host
            defaultNode["username"] = un
            defaultNode["password"] = pw
            defaultNode["id"] = randomString(length: 7)
            defaultNode["isSSH"] = false
            defaultNode["isActive"] = true
            defaultNode["isDefault"] = true
            defaultNode["isRPC"] = true
            defaultNode["label"] = "Testing Node"
            
            let saveDef = cd.saveCredentialsToCoreData(vc: vc, credentials: defaultNode)
            
            if saveDef {
                
                print("default node saved")
                //delete from user defaults
                userDefaults.set(true, forKey: "hasConverted")
                
            } else {
                
                print("failed to save default node")
                
            }
            
        }
        
        if credentialsExist {
            
            let decPort = aes.decryptKey(keyToDecrypt: port)
            let decIp = aes.decryptKey(keyToDecrypt: ip)
            let decUsername = aes.decryptKey(keyToDecrypt: username)
            let decPass = aes.decryptKey(keyToDecrypt: password)
            
            if decPort != "18332" && decIp != "46.101.239.249" && decUsername != "bitcoin" && decPass != "password" {
                
                credentials["label"] = "Your Node - tap to edit"
                credentials["isActive"] = true
                credentials["isDefault"] = false
                
                let success = cd.saveCredentialsToCoreData(vc: vc, credentials: credentials)
                
                if success {
                    
                    print("Converted credentials to coredata")
                    userDefaults.set(true, forKey: "hasConverted")
                    
                } else {
                    
                    print("failed to ocnvert credentials to coredata")
                    
                }
                
                
            } else {
                
                saveDefaultNode()
                
            }
            
        } else {
            
            saveDefaultNode()
            
        }
        
    }
    
}
