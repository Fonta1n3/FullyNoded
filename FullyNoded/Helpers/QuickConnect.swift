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
    /// clightning-rpc://rpcuser:rpcpassword@kjhfefe.onion:1312?label=BTCPay%20C-Lightning
    /// lndconnect://hbdfhjwbfwbfhwbj.onion:8080?cert=xxx&macaroon=xxx
    /// JOINMARKET http://kjwdfkjbdkcjb.onion:28183?cert=xxx
    
    static var uncleJim = false
    
    class func addNode(uncleJim: Bool, url: String, completion: @escaping ((success: Bool, errorMessage: String?)) -> Void) {
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
        
        if url.hasPrefix("lndconnect://") {
            
            guard let macaroon = URL(string: url)?.value(for: "macaroon"),
                  let cert = URL(string: url)?.value(for: "cert") else {
                      completion((false, "Credentials missing."))
                      return
                  }
                        
            guard let certData = try? Data.decodeUrlSafeBase64(cert) else {
                completion((false, "Error decoding cert."))
                return
            }
            
            guard let macData = try? Data.decodeUrlSafeBase64(macaroon) else {
                completion((false, "Error decoding macaroon."))
                return
            }
            
            // Encrypt credentials
            guard let encryptedMacaroonHex = Crypto.encrypt(macData.hexString.dataUsingUTF8StringEncoding),
                  let encryptedCert = Crypto.encrypt(certData) else {
                    completion((false, "Error encrypting your credentials."))
                    return
            }
            
            newNode["onionAddress"] = torNodeHost
            newNode["label"] = "LND"
            newNode["uncleJim"] = false
            newNode["isLightning"] = true
            newNode["isActive"] = true
            newNode["macaroon"] = encryptedMacaroonHex
            newNode["cert"] = encryptedCert
            
            processNode(newNode, url, completion: completion)
            
        } else {
            guard let rpcPassword = URLComponents(string: url)?.password,
                let rpcUser = URLComponents(string: url)?.user else {
                    // try jm here.
                    guard let certCheck = URL(string: url)?.value(for: "cert"),
                          let certData = try? Data.decodeUrlSafeBase64(certCheck) else {
                              completion((false, "cert missing."))
                              return
                          }
                    
                    guard let encryptedCert = Crypto.encrypt(certData) else {
                            completion((false, "error encrypting your credentials"))
                            return
                    }
                    
                    newNode["cert"] = encryptedCert
                    newNode["onionAddress"] = torNodeHost
                    newNode["isLightning"] = false
                    newNode["isActive"] = true
                    newNode["uncleJim"] = false
                    newNode["label"] = "Join Market"
                    newNode["isJoinMarket"] = true
                    processNode(newNode, url, completion: completion)
                    return
            }
                        
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
            newNode["uncleJim"] = uncleJim
            newNode["isActive"] = true
            
            if !url.hasPrefix("clightning-rpc") && rpcUser != "lightning" {
                newNode["isLightning"] = false
            } else {
                newNode["isLightning"] = true
            }
            
            processNode(newNode, url, completion: completion)
        }
    }
    
    private class func processNode(_ newNode: [String:Any], _ url: String, completion: @escaping ((success: Bool, errorMessage: String?)) -> Void) {
        CoreDataService.retrieveEntity(entityName: .newNodes) { (nodes) in
            guard let nodes = nodes, nodes.count > 0 else { saveNode(newNode, url, completion: completion); return }
            
            for (i, existingNode) in nodes.enumerated() {
                let existingNodeStruct = NodeStruct(dictionary: existingNode)
                if let existingNodeId = existingNodeStruct.id {
                    switch url {
                    case _ where url.hasPrefix("btcrpc")  || url.hasPrefix("btcstandup"):
                        
                        if !existingNodeStruct.isLightning && !existingNodeStruct.isJoinMarket {
                            CoreDataService.update(id: existingNodeId, keyToUpdate: "isActive", newValue: false, entity: .newNodes) { _ in }
                        }
                        
                    case _ where url.hasPrefix("clightning-rpc"), _ where url.hasPrefix("lndconnect"):
                        
                        if existingNodeStruct.isActive && existingNodeStruct.isLightning {
                            CoreDataService.update(id: existingNodeId, keyToUpdate: "isActive", newValue: false, entity: .newNodes) { _ in }
                        }
                        
                    case _ where url.hasPrefix("http"):
                        
                        if existingNodeStruct.isActive && existingNodeStruct.isJoinMarket {
                            CoreDataService.update(id: existingNodeId, keyToUpdate: "isActive", newValue: false, entity: .newNodes) { _ in }
                        }
                        
                    default:
                        #if DEBUG
                        print("default")
                        #endif
                    }
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
                if !url.hasPrefix("clightning-rpc") && !url.hasPrefix("lndconnect") && !uncleJim {
                    UserDefaults.standard.removeObject(forKey: "walletName")
                }
                
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
