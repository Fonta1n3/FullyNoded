//
//  MakeRPCCall.swift
//  BitSense
//
//  Created by Peter on 31/03/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class MakeRPCCall {
        
    static let sharedInstance = MakeRPCCall()
    let torClient = TorClient.sharedInstance
    private var attempts = 0
    var connected:Bool = false
    var onDoneBlock : (((response: Any?, errorDesc: String?)) -> Void)?
    var activeNode:NodeStruct?
    var lastSentId:String?
    
    
    private init() {}

    
    func connectToRelay(node: NodeStruct) {
        StreamManager.shared.node = node
        let urlString = UserDefaults.standard.string(forKey: "nostrRelay") ?? "wss://nostr-relay.wlvs.space"
        StreamManager.shared.openWebSocket(urlString: urlString)
    }
    
    func getActiveNode(completion: @escaping ((NodeStruct?) -> Void)) {
        CoreDataService.retrieveEntity(entityName: .newNodes) { nodes in
            guard let nodes = nodes, nodes.count > 0 else {
                completion((nil))
                return
            }
            var activeNode: [String:Any]?
            for node in nodes {
                if let isActive = node["isActive"] as? Bool,
                   let isLightning = node["isLightning"] as? Bool,
                   !isLightning,
                   !(node["isJoinMarket"] as? Bool ?? false) {
                    if isActive {
                        activeNode = node
                    }
                }
            }
            guard let active = activeNode else {
                completion((nil))
                return
            }
            
            let n = NodeStruct(dictionary: active)
            self.activeNode = n
            completion(n)
        }
    }
    
    
    func executeNostrRpc(method: BTC_CLI_COMMAND) {
        let id = UUID()
        StreamManager.shared.lastSentId = id.uuidString
        
        var walletName:String?
        if isWalletRPC(command: method) {
            walletName = UserDefaults.standard.string(forKey: "walletName")
        }
        let chain = UserDefaults.standard.object(forKey: "chain") as? String ?? "main"
        #if DEBUG
        print("chain: \(chain)")
        #endif
        var port = 8332
        switch chain {
        case "test":
            port = 18332
        case "regtest":
            port = 18443
        case "signet":
            port = 38332
        default:
            break
        }
        
        let dict:[String:Any] = [
            "request_id": id.uuidString,
            "port": port,
            "command":method.stringValue,
            "param":method.paramDict,
            "wallet":walletName ?? "",
            "http_method": "POST"
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else {
            #if DEBUG
            print("converting to jsonData failing...")
            #endif
            return
        }
        guard let node = activeNode,
              let encryptedWords = node.nostrWords,
            let decryptedWords = Crypto.decrypt(encryptedWords),
              let words = decryptedWords.utf8String else { onDoneBlock!((nil, "Error encrypting content...")); return }
        
        let encryptedContent = Crypto.encryptNostr(jsonData, words)!.base64EncodedString()
        StreamManager.shared.writeEvent(content: encryptedContent)
    }
    
    
    func executeNostrJmRpc(method: JM_REST, httpMethod: String, token: String?, httpBody: [String:Any]?) {
        let id = UUID()
        StreamManager.shared.lastSentId = id.uuidString
        
        var dict:[String:Any] = [
            "port": 28183,
            "http_method": httpMethod,
            "url_path": method.stringValue,
            "request_id": id.uuidString
        ]
        if let httpBody = httpBody {
            dict["http_body"] = httpBody
        }
        if let token = token {
            dict["token"] = token
        }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else {
            #if DEBUG
            print("converting to jsonData failing...")
            #endif
            return
        }
        guard let node = activeNode,
              let encryptedWords = node.nostrWords,
            let decryptedWords = Crypto.decrypt(encryptedWords),
              let words = decryptedWords.utf8String else { onDoneBlock!((nil, "Error encrypting content...")); return }
        
        let encryptedContent = Crypto.encryptNostr(jsonData, words)!.base64EncodedString()
        StreamManager.shared.writeEvent(content: encryptedContent)
    }
    
    
    func executeClnNostrRpc(http_body: [String:Any]) {
        let id = UUID()
        StreamManager.shared.lastSentId = id.uuidString
        let dict:[String:Any] = [
            "request_id": id.uuidString,
            "port": 9737,
            "http_body":http_body
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else {
            #if DEBUG
            print("converting to jsonData failing...")
            #endif
            return
        }
        guard let node = activeNode,
              let encryptedWords = node.nostrWords,
            let decryptedWords = Crypto.decrypt(encryptedWords),
              let words = decryptedWords.utf8String else { onDoneBlock!((nil, "Error encrypting content...")); return }
        
        let encryptedContent = Crypto.encryptNostr(jsonData, words)!.base64EncodedString()
        StreamManager.shared.writeEvent(content: encryptedContent)
    }
    
    
    func executeRPCCommand(method: BTC_CLI_COMMAND, completion: @escaping ((response: Any?, errorDesc: String?)) -> Void) {
        attempts += 1
        if let node = self.activeNode {
            if node.isNostr {
                if StreamManager.shared.connected {
                    self.executeNostrRpc(method: method)
                } else {
                    StreamManager.shared.eoseReceivedBlock = { subscribed in
                        if subscribed {
                            self.executeNostrRpc(method: method)
                        } else {
                            completion((nil, "Not subscribed to relay after attempting to auto reconnect."))
                        }
                    }
                    self.connectToRelay(node: node)
                }
            } else {
                guard let encAddress = node.onionAddress,
                        let encUser = node.rpcuser,
                        let encPassword = node.rpcpassword else {
                    completion((nil, "error getting encrypted node credentials"))
                    return
                }
                
                let onionAddress = decryptedValue(encAddress)
                let rpcusername = decryptedValue(encUser)
                let rpcpassword = decryptedValue(encPassword)
                
                guard onionAddress != "", rpcusername != "", rpcpassword != "" else {
                    completion((nil, "error decrypting node credentials"))
                    return
                }
                
                var walletUrl = "http://\(rpcusername):\(rpcpassword)@\(onionAddress)"
                let ud = UserDefaults.standard
                
                if ud.object(forKey: "walletName") != nil {
                    if let walletName = ud.object(forKey: "walletName") as? String {
                        let b = isWalletRPC(command: method)
                        if b {
                            walletUrl += "/wallet/" + walletName
                        }
                    }
                }
                
                guard let url = URL(string: walletUrl) else {
                    completion((nil, "url error"))
                    return
                }
                
                var request = URLRequest(url: url)
                var timeout = 10.0
                
                switch method {
                case .gettxoutsetinfo:
                    timeout = 1000.0
                    
                case .importmulti, .deriveaddresses, .loadwallet:
                    timeout = 60.0
                    
                default:
                    break
                }
                
                let loginString = String(format: "%@:%@", rpcusername, rpcpassword)
                let loginData = loginString.data(using: String.Encoding.utf8)!
                let base64LoginString = loginData.base64EncodedString()
                let id = UUID().uuidString
                
                request.timeoutInterval = timeout
                request.httpMethod = "POST"
                request.addValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
                request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
                
                let dict:[String:Any] = ["jsonrpc":"1.0","id":id,"method":method.stringValue,"params":method.paramDict]
                
                guard let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else {
                    #if DEBUG
                    print("converting to jsonData failing...")
                    #endif
                    return
                }
                
                request.httpBody = jsonData
                
                #if DEBUG
                print("url = \(url)")
                print("request: \(dict)")
                #endif
                
                var sesh = URLSession(configuration: .default)
                
                if onionAddress.contains("onion") {
                    sesh = self.torClient.session
                }
                
                let task = sesh.dataTask(with: request as URLRequest) { [weak self] (data, response, error) in
                    guard let self = self else { return }
                    
                    guard let urlContent = data else {
                        
                        guard let error = error else {
                            if self.attempts < 20 {
                                self.executeRPCCommand(method: method, completion: completion)
                            } else {
                                self.attempts = 0
                                completion((nil, "Unknown error, ran out of attempts"))
                            }
                            
                            return
                        }
                        
                        if self.attempts < 20 {
                            self.executeRPCCommand(method: method, completion: completion)
                        } else {
                            self.attempts = 0
                            completion((nil, error.localizedDescription))
                        }
                        
                        return
                    }
                    
                    self.attempts = 0
                    
                    guard let json = try? JSONSerialization.jsonObject(with: urlContent, options: .mutableLeaves) as? NSDictionary else {
                        if let httpResponse = response as? HTTPURLResponse {
                            switch httpResponse.statusCode {
                            case 401:
                                completion((nil, "Looks like your rpc credentials are incorrect, please double check them. If you changed your rpc creds in your bitcoin.conf you need to restart your node for the changes to take effect."))
                            case 403:
                                completion((nil, "The bitcoin-cli \(method) command has not been added to your rpcwhitelist, add \(method) to your bitcoin.conf rpcwhitelsist, reboot Bitcoin Core and try again."))
                            default:
                                completion((nil, "Unable to decode the response from your node, http status code: \(httpResponse.statusCode)"))
                            }
                        } else {
                            completion((nil, "Unable to decode the response from your node..."))
                        }
                        return
                    }
                    
                    #if DEBUG
                    print("json: \(json)")
                    #endif
                    
                    guard let errorCheck = json["error"] as? NSDictionary else {
                        completion((json["result"], nil))
                        return
                    }
                    
                    guard let errorMessage = errorCheck["message"] as? String else {
                        completion((nil, "Uknown error from bitcoind"))
                        return
                    }
                    
                    completion((nil, errorMessage))
                }
                
                task.resume()
            }
        } else {
            completion((nil, "No active Bitcoin Core node."))
            return
        }
    }
}

extension String {
    func split(by length: Int) -> [String] {
        var startIndex = self.startIndex
        var results = [Substring]()
        
        while startIndex < self.endIndex {
            let endIndex = self.index(startIndex, offsetBy: length, limitedBy: self.endIndex) ?? self.endIndex
            results.append(self[startIndex..<endIndex])
            startIndex = endIndex
        }
        
        return results.map { String($0) }
    }
}



