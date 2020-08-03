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
    
    // MARK: QuickConnect url examples
    // btcstandup://rpcuser:rpcpassword@uhqefiu873h827h3ufnjecnkajbciw7bui3hbuf233b.onion:8332/?label=Node%20Name
    // btcstandup://rpcuser:rpcpassword@uhqefiu873h827h3ufnjecnkajbciw7bui3hbuf233b.onion:18332/?
    // btcstandup://rpcuser:rpcpassword@uhqefiu873h827h3ufnjecnkajbciw7bui3hbuf233b.onion:18443?
    
    class func addNode(url: String, completion: @escaping ((success: Bool, errorMessage: String?)) -> Void) {
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
            completion((false, "not a valid url"))
        }
        
        guard host != "", rpcUser != "", rpcPassword != "" else {
            completion((false, "either the hostname, rpcuser or rpcpassword is empty"))
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
        
        var newNode = [String:Any]()
        
        guard let torNodeHost = encryptedValue(host.dataUsingUTF8StringEncoding) else {
            completion((false, "error encrypting your hostname"))
            return
        }
        
        guard let torNodeRPCPass = encryptedValue(rpcPassword.dataUsingUTF8StringEncoding) else {
            completion((false, "error encrypting your rpc password"))
            return
        }
        
        guard let torNodeRPCUser = encryptedValue(rpcUser.dataUsingUTF8StringEncoding) else {
            completion((false, "error encrypting your rpc user"))
            return
        }
        
        if rpcUser.isAlphanumeric && rpcPassword.isAlphanumeric {
            newNode["id"] = UUID()
            newNode["onionAddress"] = torNodeHost
            newNode["label"] = label
            newNode["rpcuser"] = torNodeRPCUser
            newNode["rpcpassword"] = torNodeRPCPass
            newNode["isActive"] = true
            
            func addNode() {
                CoreDataService.saveEntity(dict: newNode, entityName: .newNodes) { success in
                    if success {
                        let ud = UserDefaults.standard
                        ud.removeObject(forKey: "walletName")
                        completion((true, nil))
                    } else {
                        completion((false, "error saving your node to core data"))
                    }
                }
            }
            
            CoreDataService.retrieveEntity(entityName: .newNodes) { (nodes) in
                if nodes != nil {
                    if nodes!.count > 0 {
                        for (i, node) in nodes!.enumerated() {
                            let nodeStruct = NodeStruct(dictionary: node)
                            if nodeStruct.id != nil {
                                CoreDataService.update(id: nodeStruct.id!, keyToUpdate: "isActive", newValue: false, entity: .newNodes) { _ in
                                    if i + 1 == nodes!.count {
                                        addNode()
                                    }
                                }
                            }
                        }
                    } else {
                        addNode()
                    }
                } else {
                    addNode()
                }
            }
        } else {
            completion((false, "Only alphanumeric characters allowed in the rpcuser and rpcpassword fields. Edit your bitcoin.conf so that no special characters are included in your rpc credentials."))
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
