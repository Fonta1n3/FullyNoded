//
//  QuickConnect.swift
//  BitSense
//
//  Created by Peter on 28/10/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation
import UIKit

class QuickConnect {
    
    let aes = AESService()
    let cd = CoreDataService()
    var errorBool = Bool()
    var errorDescription = ""
    
    //old url format: btcrpc://kjhfefe.onion:8332?user=rpcuser&password=rpcpassword?label=nodeName?v2password=uenfieufnuf4
    
    //new format: btcrpc://rpcuser:rpcpassword@kjhfefe.onion:8332?label=nodeName&v2password=uenfieufnuf4
    
    func addNode(vc: UIViewController, url: String, completion: @escaping () -> Void) {
        
        let nodes = cd.retrieveEntity(entityName: .nodes)
        var host = ""
        var rpcPassword = ""
        var rpcUser = ""
        var label = "Node"
        var v2password = ""
        
        if let params = URLComponents(string: url)?.queryItems {
            
            if let hostCheck = URLComponents(string: url)?.host {
                
                host = hostCheck
                
            }
            
            if let portCheck = URLComponents(string: url)?.port {
                
                host += ":" + String(portCheck)
                
            }
            
            if let rpcPasswordCheck = URLComponents(string: url)?.password {
                
                rpcPassword = rpcPasswordCheck
                
            }
            
            if let rpcUserCheck = URLComponents(string: url)?.user {
                
                rpcUser = rpcUserCheck
                
            }
            
            if rpcUser == "" && rpcPassword == "" {
                
                print("old format")
                
                if params.count == 2 {
                   
                    rpcUser = (params[0].description).replacingOccurrences(of: "user=", with: "")
                    rpcPassword = (params[1].description).replacingOccurrences(of: "password=", with: "")
                    
                    if rpcPassword.contains("?label=") {
                        
                        let arr = rpcPassword.components(separatedBy: "?label=")
                        rpcPassword = arr[0]
                        
                        if arr.count > 1 {
                            
                            label = arr[1]
                        
                        }
                        
                    }
                    
                }
                
            } else {
                
                print("new format")
                let url = URL(string: url)
                
                if let labelCheck = url?.value(for: "label") {
                    
                    label = labelCheck
                    
                }
                
                if let v2Check = url?.value(for: "v2password") {
                    
                    v2password = v2Check
                    
                }
                
            }
            
        } else {
            
            errorBool = true
            errorDescription = "incompatible url"
            completion()
            
        }
        
        print("label = \(label)")
        print("host = \(host)")
        print("rpcuser = \(rpcUser)")
        print("rpcpassword = \(rpcPassword)")
        print("v2Password = \(v2password)")
        
        guard host != "", rpcUser != "", rpcPassword != "" else {
            errorBool = true
            errorDescription = "incomplete node credentials"
            completion()
            return
        }
        
        var node = [String:Any]()
        let torNodeId = randomString(length: 23)
        let torNodeHost = aes.encryptKey(keyToEncrypt: host)
        let torNodeRPCPass = aes.encryptKey(keyToEncrypt: rpcPassword)
        let torNodeRPCUser = aes.encryptKey(keyToEncrypt: rpcUser)
        let torNodeLabel = aes.encryptKey(keyToEncrypt: label)
        let torNodeV2Password = aes.encryptKey(keyToEncrypt: v2password)
        
        node["id"] = torNodeId
        node["onionAddress"] = torNodeHost
        node["label"] = torNodeLabel
        node["rpcuser"] = torNodeRPCUser
        node["rpcpassword"] = torNodeRPCPass
        node["usingSSH"] = false
        node["isDefault"] = false
        node["usingTor"] = true
        node["isActive"] = true
        
        if v2password != "" {
            
            node["v2password"] = torNodeV2Password
            
        }
                
        let success = cd.saveEntity(vc: vc,
                                    dict: node,
                                    entityName: .nodes)
        
        if success {
            
            print("btcrpc node added")
            
            if nodes.count > 1 {
               
                deActivateOtherNodes(nodes: nodes,
                                     nodeID: torNodeId,
                                     cd: cd,
                                     vc: vc,
                                     completion: completion)
                
            } else {
                
                errorBool = false
                completion()
                
            }
            
        } else {
            
            errorBool = true
            errorDescription = "Error adding QuickConnect node"
            completion()
            
        }
        
    }
    
    private func deActivateOtherNodes(nodes: [[String:Any]], nodeID: String, cd: CoreDataService, vc: UIViewController, completion: @escaping () -> Void) {
        
        if SSHService.sharedInstance.session != nil {
            
            if SSHService.sharedInstance.session.isConnected {
                
                SSHService.sharedInstance.disconnect()
                SSHService.sharedInstance.commandExecuting = false
                
            }
            
        }
        
        for node in nodes {
            
            let str = NodeStruct(dictionary: node)
            let id = str.id
            let isActive = str.isActive
            
            if id != nodeID && isActive {
                
                let success = cd.updateEntity(viewController: vc,
                                              id: id,
                                              newValue: false,
                                              keyToEdit: "isActive",
                                              entityName: .nodes)
                
                if success {
                    
                    print("nodes deactivated")
                    errorBool = false
                    completion()
                    
                } else {
                    
                    errorBool = true
                    errorDescription = "Node added but there was an error deactiving your other nodes"
                    completion()
                    
                }
                
            }
            
        }
        
    }
    
}

extension URL {

  func value(for paramater: String) -> String? {

    let queryItems = URLComponents(string: self.absoluteString)?.queryItems
    let queryItem = queryItems?.filter({$0.name == paramater}).first
    let value = queryItem?.value

    return value
  }

}
