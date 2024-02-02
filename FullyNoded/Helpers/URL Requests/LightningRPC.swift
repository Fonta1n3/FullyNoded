//
//  LightningRPC.swift
//  FullyNoded
//
//  Created by Peter on 02/08/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

class LightningRPC {
    
    static let sharedInstance = LightningRPC()
    static let torClient = TorClient.sharedInstance
    static var attempts = 0
    private var isNostr = false
    
    private init() {}
    
    private func viaNostr(http_body: [String:Any], completion: @escaping ((id: UUID, response: Any?, errorDesc: String?)) -> Void) {
        MakeRPCCall.sharedInstance.executeClnNostrRpc(http_body: http_body)
        
        StreamManager.shared.onDoneBlock = { nostrResponse in
            guard let response = nostrResponse.response as? [String:Any] else {
                completion((UUID(), nil, nostrResponse.errorDesc))
                return
            }
            
            #if DEBUG
            print("response: \(response)")
            #endif
            
            guard let message = response["message"] as? String else {
                completion((UUID(), response, nil))
                return
            }
            
            completion((UUID(), nil, message))
        }
    }
    
    func command(id: UUID, method: LIGHTNING_CLI, param: Any?, completion: @escaping ((id: UUID, response: Any?, errorDesc: String?)) -> Void) {
        CoreDataService.retrieveEntity(entityName: .newNodes) { [weak self] nodes in
            guard let self = self else { return }
            
            guard let nodes = nodes else {
                completion((id, nil, "error getting nodes from core data"))
                return
            }
            
            var potentialLightningNode: [String:Any]?
            var potentialAddress: String?
            var potentialSparkoKey: String?
            
            for node in nodes {
                let n = NodeStruct(dictionary: node)
                if n.isActive && n.isNostr {
                    self.isNostr = true
                }
                if n.isLightning, n.isActive {
                    potentialLightningNode = node
                }
            }
            
            let dict:[String:Any] = ["jsonrpc":"2.0","id":id.uuidString,"method":method.rawValue,"params":param ?? nil]
            
            if self.isNostr {
                self.viaNostr(http_body: dict, completion: completion)
            } else {
                
                guard let lightningNode = potentialLightningNode else {
                    completion((id, nil, "no lightning node"))
                    return
                }
                let node = NodeStruct(dictionary: lightningNode)
                var sesh = URLSession(configuration: .default)
                
                if let encAddress = node.onionAddress {
                    potentialAddress = decryptedValue(encAddress)
                    if let add = potentialAddress, add.contains("onion") {
                        sesh = LightningRPC.torClient.session
                    }
                }
                
                if let encSparkoKey = node.rpcpassword {
                    potentialSparkoKey = decryptedValue(encSparkoKey)
                }
                
                guard let sparkoKey = potentialSparkoKey else { return }
                
                let lightningUrl = "http://\(potentialAddress ?? "localhost:9737")/rpc"
                
                guard let url = URL(string: lightningUrl) else {
                    completion((id, nil, "url error"))
                    return
                }
                
                var request = URLRequest(url: url)
                
                switch method {
                case .rebalance:
                    request.timeoutInterval = 120
                case .recvmsg:
                    request.timeoutInterval = 180
                case .connect:
                    request.timeoutInterval = 90
                default:
                    break
                }
                
                request.addValue(sparkoKey, forHTTPHeaderField: "X-Access")
                request.httpMethod = "POST"
                
                guard let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else {
                    #if DEBUG
                    print("converting to jsonData failing...")
                    #endif
                    return
                }
                
                request.httpBody = jsonData
                
                #if DEBUG
                print("url = \(url)")
                print("request: \("{\"method\":\"\(method.rawValue)\",\"params\":[\(param)]}")")
                #endif
                
                let task = sesh.dataTask(with: request as URLRequest) { (data, response, error) in
                    guard error == nil else {
                        #if DEBUG
                        print("error: \(error!.localizedDescription)")
                        #endif
                        
                        completion((id, nil, error!.localizedDescription))
                        return
                    }
                    
                    guard let urlContent = data else {
                        completion((id, nil, "Tor client session data is nil"))
                        return
                    }
                    
                    guard let jsonResult = try? JSONSerialization.jsonObject(with: urlContent, options: .mutableLeaves) as? [String:Any] else {
                        completion((id, nil, "Error serializing."))
                        return
                    }
                    
                    #if DEBUG
                    print("urlContent: \(urlContent)")
                    print("jsonResult: \(jsonResult)")
                    #endif
                    
                    if let error = jsonResult["error"] as? [String:Any] {
                        if let errorMessage = error["message"] as? String {
                            completion((id, nil, errorMessage))
                        } else {
                            completion((id, nil, "Unknown error"))
                        }
                    } else {
                        completion((id, jsonResult, nil))
                    }
                }
                task.resume()
            }
        }
    }
    
}
