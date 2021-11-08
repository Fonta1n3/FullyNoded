//
//  LightningRPC.swift
//  FullyNoded
//
//  Created by Peter on 02/08/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

class LightningRPC {

    static let torClient = TorClient.sharedInstance
    static var attempts = 0
    
    class func command(id: UUID, method: LIGHTNING_CLI, param: Any, completion: @escaping ((id: UUID, response: Any?, errorDesc: String?)) -> Void) {
        
        var rpcusername = ""
        var rpcpassword = ""
        var onionAddress = ""
        
        CoreDataService.retrieveEntity(entityName: .newNodes) { nodes in
            guard let nodes = nodes else {
                completion((id, nil, "error getting nodes from core data"))
                return
            }

            var potentialLightningNode: [String:Any]?
            
            for node in nodes {
                if let isLightning = node["isLightning"] as? Bool, isLightning, let isActive = node["isActive"] as? Bool, isActive {
                    potentialLightningNode = node
                }
            }
            
            guard let lightningNode = potentialLightningNode else {
                completion((id, nil, "no lightning node"))
                return
            }
            
            let node = NodeStruct(dictionary: lightningNode)
            
            if let encAddress = node.onionAddress {
                onionAddress = decryptedValue(encAddress)
            }
            if let encUser = node.rpcuser {
                rpcusername = decryptedValue(encUser)
            }
            if let encPassword = node.rpcpassword {
                rpcpassword = decryptedValue(encPassword)
            }
            
            let lightningUrl = "http://\(rpcusername):\(rpcpassword)@\(onionAddress)"
            
            guard let url = URL(string: lightningUrl) else {
                completion((id, nil, "url error"))
                return
            }
            
            var request = URLRequest(url: url)
            let loginString = String(format: "%@:%@", rpcusername, rpcpassword)
            let loginData = loginString.data(using: String.Encoding.utf8)!
            let base64LoginString = loginData.base64EncodedString()
            
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
            
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.addValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
            request.httpMethod = "POST"
            request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
            request.httpBody = "{\"jsonrpc\":\"2.0\",\"id\":\"\(id)\",\"method\":\"\(method.rawValue)\",\"params\":[\(param)]}".data(using: .utf8)
            
            #if DEBUG
            print("url = \(url)")
            print("request: \("{\"jsonrpc\":\"2.0\",\"id\":\"\(id)\",\"method\":\"\(method.rawValue)\",\"params\":[\(param)]}")")
            #endif
            
            var sesh = URLSession(configuration: .default)
            
            if onionAddress.contains("onion") {
                sesh = self.torClient.session
            }
            
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
                
                guard let jsonAddressResult = try? JSONSerialization.jsonObject(with: urlContent,
                                                                                options: JSONSerialization.ReadingOptions.mutableLeaves) as? NSDictionary else {
                    completion((id, nil, "Error serializing."))
                    return
                }
                
                #if DEBUG
                print("json: \(jsonAddressResult)")
                #endif
                
                if let error = jsonAddressResult["error"] as? NSDictionary { // Error path
                    
                    if let errorMessage = error["message"] as? String {
                        completion((id, nil, errorMessage))
                    } else {
                        completion((id, nil, "Unknown error"))
                    }
                } else { // Success path
                    completion((id, jsonAddressResult["result"], nil))
                }
            }
            task.resume()
        }
    }
    
}
