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
    
    // MARK: QuickConnect url examples
    // btcstandup://rpcuser:rpcpassword@uhqefiu873h827h3ufnjecnkajbciw7bui3hbuf233b.onion:8332/?label=Node%20Name
    // btcstandup://rpcuser:rpcpassword@uhqefiu873h827h3ufnjecnkajbciw7bui3hbuf233b.onion:18332/?
    // btcstandup://rpcuser:rpcpassword@uhqefiu873h827h3ufnjecnkajbciw7bui3hbuf233b.onion:18443?
    
    func addNode(vc: UIViewController, url: String, completion: @escaping () -> Void) {
        
        cd.retrieveEntity(entityName: .nodes) {
            
            if !self.cd.errorBool {
                
                let nodes = self.cd.entities
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
                        
                        let url = URL(string: url)
                        
                        if let labelCheck = url?.value(for: "label") {
                            
                            label = labelCheck
                            
                        }
                        
                        if let v2Check = url?.value(for: "v2password") {
                            
                            v2password = v2Check
                            
                        }
                        
                    }
                    
                } else {
                    
                    self.errorBool = true
                    completion()
                    
                }
                
                guard host != "", rpcUser != "", rpcPassword != "" else {
                    self.errorBool = true
                    completion()
                    return
                }
                
                var node = [String:Any]()
                let torNodeId = randomString(length: 23)
                let torNodeHost = self.aes.encryptKey(keyToEncrypt: host)
                let torNodeRPCPass = self.aes.encryptKey(keyToEncrypt: rpcPassword)
                let torNodeRPCUser = self.aes.encryptKey(keyToEncrypt: rpcUser)
                let torNodeLabel = self.aes.encryptKey(keyToEncrypt: label)
                let torNodeV2Password = self.aes.encryptKey(keyToEncrypt: v2password)
                
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
                                
                self.cd.saveEntity(dict: node, entityName: .nodes) {
                    
                    if !self.cd.errorBool {
                        
                        let success = self.cd.boolToReturn
                        
                        if success {
                            
                            print("standup node added")
                            
                            if nodes.count > 0 {
                                
                                let ud = UserDefaults.standard
                                ud.removeObject(forKey: "walletName")
                                
                                self.deActivateOtherNodes(nodes: nodes,
                                                          nodeID: torNodeId,
                                                          cd: self.cd,
                                                          vc: vc,
                                                          completion: completion)
                                
                            } else {
                                
                                self.errorBool = false
                                completion()
                                
                            }
                            
                        } else {
                            
                            self.errorBool = true
                            self.errorDescription = "Error adding QuickConnect node"
                            completion()
                            
                        }
                        
                    } else {
                        
                        self.errorBool = true
                        self.errorDescription = self.cd.errorDescription
                        completion()
                        
                    }
                    
                }
                
            } else {
                
                self.errorBool = true
                self.errorDescription = "Error adding getting nodes from core data"
                completion()
                
            }
            
        }
        
    }
    
    private func deActivateOtherNodes(nodes: [[String:Any]], nodeID: String, cd: CoreDataService, vc: UIViewController, completion: @escaping () -> Void) {
        
        if nodes.count > 1 {
            
            for node in nodes {
                
                let str = NodeStruct(dictionary: node)
                let id = str.id
                let isActive = str.isActive
                
                if id != nodeID && isActive {
                    
                    let d1:[String:Any] = ["id":id,"newValue":false,"keyToEdit":"isActive","entityName":ENTITY.nodes]
                    
                    cd.updateEntity(dictsToUpdate: [d1]) {
                        
                        if !cd.errorBool {
                            
                            let success = cd.boolToReturn
                            
                            if success {
                                
                                self.errorBool = false
                                
                            } else {
                                
                                self.errorBool = true
                                self.errorDescription = "Node added but there was an error deactiving your other nodes"
                                completion()
                                
                            }
                            
                        } else {
                            
                            self.errorBool = true
                            self.errorDescription = cd.errorDescription
                            completion()
                            
                        }
                        
                    }
                    
                }
                
            }
            
            goHome()
                        
        } else {
            
            goHome()
            
        }
                
    }
    
    private func goHome() {
        
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            
            let window = appDelegate.window
            
            if let myTabBar = window?.rootViewController as? UITabBarController {
                
                DispatchQueue.main.async {
                    
                    myTabBar.selectedIndex = 0
                    
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
