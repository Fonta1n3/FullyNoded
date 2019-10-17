//
//  FirstTime.swift
//  BitSense
//
//  Created by Peter on 05/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation
import KeychainSwift

class FirstTime {
    
    let aes = AESService()
    let cd = CoreDataService()
    let ud = UserDefaults.standard
    
    func firstTimeHere() {
        print("firstTimeHere")
        
        if ud.object(forKey: "firstTime") == nil {
            
            let password = randomString(length: 32)
            let keychain = KeychainSwift()
            
            if ud.string(forKey: "UnlockPassword") != nil {
                
                keychain.set(ud.string(forKey: "UnlockPassword")!, forKey: "UnlockPassword")
                ud.removeObject(forKey: "UnlockPassword")
                
            }
            
            if keychain.set(password, forKey: "AESPassword") {
                
                print("keychain set AESPassword succesfully")
                ud.set(true, forKey: "firstTime")
                ud.set(true, forKey: "updatedToSwift5")
            
            } else {
                
                print("error setting AESPassword in keychain")
                
            }
            
        }
        
        if ud.object(forKey: "testNodeAdded") == nil {
            
            var newNode = [String:Any]()
            let id = randomString(length: 23)
            let encHost = aes.encryptKey(keyToEncrypt: "bitcoin")
            let encIP = aes.encryptKey(keyToEncrypt: "167.71.32.16")
            let encPort = aes.encryptKey(keyToEncrypt: "6500")
            let encPassword = aes.encryptKey(keyToEncrypt: "lul1b13s")
            let encRPCPort = aes.encryptKey(keyToEncrypt: "18332")
            let encRPCPass = aes.encryptKey(keyToEncrypt: "password")
            let encRPCUser = aes.encryptKey(keyToEncrypt: "bitcoin")
            let encLabel = aes.encryptKey(keyToEncrypt: "Testing Node")
            
            newNode["id"] = id
            newNode["username"] = encHost
            newNode["ip"] = encIP
            newNode["port"] = encPort
            newNode["password"] = encPassword
            newNode["label"] = encLabel
            newNode["rpcuser"] = encRPCUser
            newNode["rpcpassword"] = encRPCPass
            newNode["rpcport"] = encRPCPort
            newNode["usingSSH"] = true
            newNode["isDefault"] = true
            
            let nodes = cd.retrieveEntity(entityName: ENTITY.nodes)
            
            if nodes.count > 0 {
                
                newNode["isActive"] = false
                
            } else {
                
                newNode["isActive"] = true
                
            }
            
            var torNode = [String:Any]()
            let torNodeId = randomString(length: 23)
            let torNodeHost = aes.encryptKey(keyToEncrypt: "vpcslgyyrlx2ioch7anyhgrwewbzfl2zi5pw3b274rid4nsydbmtxmyd.onion:18332")
            let torAuthKey = aes.encryptKey(keyToEncrypt: "NQ2IJRNRZWPKVJNGWV7N6KJFUS235N27IP5NZ7UAXMXWUMILNLJA")
            let torNodeRPCPass = aes.encryptKey(keyToEncrypt: "password")
            let torNodeRPCUser = aes.encryptKey(keyToEncrypt: "user")
            let torNodeLabel = aes.encryptKey(keyToEncrypt: "Tor Testing Node")
            
            torNode["id"] = torNodeId
            torNode["onionAddress"] = torNodeHost
            torNode["authKey"] = torAuthKey
            torNode["label"] = torNodeLabel
            torNode["rpcuser"] = torNodeRPCUser
            torNode["rpcpassword"] = torNodeRPCPass
            torNode["usingSSH"] = false
            torNode["isDefault"] = false
            torNode["usingTor"] = true
            
            let vc = MainMenuViewController()
            
            let success = cd.saveEntity(vc: vc,
                                        dict: newNode,
                                        entityName: .nodes)
            
            let _ = cd.saveEntity(vc: vc,
                                  dict: torNode,
                                  entityName: .nodes)
            
            if success {
                
                ud.set(true, forKey: "testNodeAdded")
                
            }
            
        }
        
    }
    
}

