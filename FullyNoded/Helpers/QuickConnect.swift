//
//  QuickConnect.swift
//  BitSense
//
//  Created by Peter on 28/10/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class QuickConnect {
    
    // MARK: QuickConnect uri examples
    /// btcrpc://rpcuser:rpcpassword@uhqefiu873h827h3ufnjecnkajbciw7bui3hbuf233b.onion:8332/?label=Node%20Name
    /// btcrpc://rpcuser:rpcpassword@uhqefiu873h827h3ufnjecnkajbciw7bui3hbuf233b.onion:18332/?
    /// btcrpc://rpcuser:rpcpassword@uhqefiu873h827h3ufnjecnkajbciw7bui3hbuf233b.onion:18443
    
    
    class func addNode(url: String, completion: @escaping ((success: Bool, errorMessage: String?)) -> Void) {
        var newNode = [String:Any]()
        newNode["id"] = UUID()
        var label = "Node"
        
        guard var host = URLComponents(string: url)?.host,
              let port = URLComponents(string: url)?.port else {
            completion((false, "invalid url"))
            return
        }
        
        host += ":" + String(port)
        
        // Encrypt credentials
        guard let torNodeHost = Crypto.encrypt(host.dataUsingUTF8StringEncoding) else {
            completion((false, "error encrypting your credentials"))
            return
        }
        
        
        guard let rpcPassword = URLComponents(string: url)?.password,
              let rpcUser = URLComponents(string: url)?.user else {
            return }
        //                    // try jm here.
        //                    guard let certCheck = URL(string: url)?.value(for: "cert"),
        //                          let certData = try? Data.decodeUrlSafeBase64(certCheck) else {
        //                              completion((false, "cert missing."))
        //                              return
        //                          }
        //
        //                    guard let encryptedCert = Crypto.encrypt(certData) else {
        //                            completion((false, "error encrypting your credentials"))
        //                            return
        //                    }
        //
        //                    newNode["cert"] = encryptedCert
        //                    newNode["onionAddress"] = torNodeHost
        //                    newNode["isLightning"] = false
        //                    newNode["isActive"] = true
        //                    newNode["uncleJim"] = false
        //                    newNode["label"] = "Join Market"
        //                    newNode["isJoinMarket"] = true
        //                    processNode(newNode, url, completion: completion)
        //                    return
        //            }
        
        if let labelCheck = URL(string: url)?.value(for: "label") {
            label = labelCheck
        }
        
        guard host != "", rpcUser != "", rpcPassword != "" else {
            completion((false, "either the hostname, rpcuser or rpcpassword is empty"))
            return
        }
        
        // Encrypt credentials
        guard let torNodeRPCPass = Crypto.encrypt(rpcPassword.dataUsingUTF8StringEncoding),
              let torNodeRPCUser = Crypto.encrypt(rpcUser.dataUsingUTF8StringEncoding) else {
            completion((false, "error encrypting your credentials"))
            return
        }
        
        newNode["onionAddress"] = torNodeHost
        newNode["label"] = label
        newNode["rpcuser"] = torNodeRPCUser
        newNode["rpcpassword"] = torNodeRPCPass
        newNode["uncleJim"] = false
        newNode["isActive"] = true
        
        processNode(newNode, url, completion: completion)
    }
    
    private class func processNode(_ newNode: [String:Any], _ url: String, completion: @escaping ((success: Bool, errorMessage: String?)) -> Void) {
        CoreDataService.retrieveEntity(entityName: .newNodes) { (nodes) in
            guard let nodes = nodes, nodes.count > 0 else { saveNode(newNode, url, completion: completion); return }
            
            for (i, existingNode) in nodes.enumerated() {
                let existingNodeStruct = NodeStruct(dictionary: existingNode)
                if let existingNodeId = existingNodeStruct.id {
                    CoreDataService.update(id: existingNodeId, keyToUpdate: "isActive", newValue: false, entity: .newNodes) { _ in }
                }
                if i + 1 == nodes.count {
                    saveNode(newNode, url, completion: completion)
                }
            }
        }
    }
    
    private class func saveNode(_ node: [String:Any], _ url: String, completion: @escaping ((success: Bool, errorMessage: String?)) -> Void) {
        CoreDataService.saveEntity(dict: node, entityName: .newNodes) { success in
            if success {
                UserDefaults.standard.removeObject(forKey: "walletName")
                
                completion((true, nil))
            } else {
                completion((false, "error saving your node to core data"))
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
