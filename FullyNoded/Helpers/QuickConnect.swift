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
        if url.lowercased().hasPrefix(NostrConnectURI.scheme + "://") {
            addNostrNode(link: url, completion: completion)
            return
        }
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
            completion((false, "Missing rpc credentials."))
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
        newNode["isActive"] = true
        
        processNode(newNode, url, completion: completion)
    }
    
    /// A Fully Noded Server Nostr Connect pairing (nostr+fullynoded://…): RPC goes through its relay.
    private class func addNostrNode(link: String, completion: @escaping ((success: Bool, errorMessage: String?)) -> Void) {
        guard let uri = NostrConnectURI(link) else {
            completion((false, "That Nostr Connect link isn't valid. Pair again in Fully Noded Server."))
            return
        }
        // The relay goes in the address field so the node list shows where it connects, and
        // (not being an onion) the node loads without waiting for Tor.
        guard let encLink = Crypto.encrypt(Data(uri.string.utf8)),
              let encAddress = Crypto.encrypt(Data(uri.relays[0].utf8)),
              let encUser = Crypto.encrypt(Data("nostr".utf8)),
              let encPassword = Crypto.encrypt(Data("nostr".utf8)) else {
            completion((false, "error encrypting your credentials"))
            return
        }
        NostrRPC.shared.reset()
        let newNode: [String: Any] = [
            "id": UUID(),
            "label": uri.label ?? "Nostr Connect",
            "onionAddress": encAddress,
            "rpcuser": encUser,
            "rpcpassword": encPassword,
            "nostrConnect": encLink,
            "isActive": true
        ]
        processNode(newNode, link, completion: completion)
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
