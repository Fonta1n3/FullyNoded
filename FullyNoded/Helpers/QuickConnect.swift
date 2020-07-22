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
    
    let cd = CoreDataService()
    var errorBool = Bool()
    var errorDescription = ""
    
    // MARK: QuickConnect url examples
    // btcstandup://rpcuser:rpcpassword@uhqefiu873h827h3ufnjecnkajbciw7bui3hbuf233b.onion:8332/?label=Node%20Name
    // btcstandup://rpcuser:rpcpassword@uhqefiu873h827h3ufnjecnkajbciw7bui3hbuf233b.onion:18332/?
    // btcstandup://rpcuser:rpcpassword@uhqefiu873h827h3ufnjecnkajbciw7bui3hbuf233b.onion:18443?
    
    func addNode(vc: UIViewController, url: String, completion: @escaping () -> Void) {
                
        var host = ""
        var rpcPassword = ""
        var rpcUser = ""
        var label = "Node"
        
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
                
            }
            
        } else {
            
            errorBool = true
            completion()
            
        }
        
        guard host != "", rpcUser != "", rpcPassword != "" else {
            errorBool = true
            completion()
            return
        }
        
        func encryptedValue(_ decryptedValue: Data) -> Data? {
            var encryptedValue:Data?
            Crypto.encryptData(dataToEncrypt: decryptedValue) { encryptedData in
                if encryptedData != nil {
                    encryptedValue = encryptedData!
                }
            }
            return encryptedValue
        }
        
        var node = [String:Any]()
        
        guard let torNodeHost = encryptedValue(host.dataUsingUTF8StringEncoding) else {
            errorBool = true
            completion()
            return
        }
        
        guard let torNodeRPCPass = encryptedValue(rpcPassword.dataUsingUTF8StringEncoding) else {
            errorBool = true
            completion()
            return
        }
        
        guard let torNodeRPCUser = encryptedValue(rpcUser.dataUsingUTF8StringEncoding) else {
            errorBool = true
            completion()
            return
        }
        
        node["id"] = UUID()
        node["onionAddress"] = torNodeHost
        node["label"] = label
        node["rpcuser"] = torNodeRPCUser
        node["rpcpassword"] = torNodeRPCPass
        node["isActive"] = true
        
        CoreDataService.saveEntity(dict: node, entityName: .newNodes) { [unowned vc = self] success in
            if success {
                let ud = UserDefaults.standard
                ud.removeObject(forKey: "walletName")
                vc.errorBool = false
                completion()
            } else {
                vc.errorBool = true
                vc.errorDescription = "Error adding QuickConnect node"
                completion()
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
