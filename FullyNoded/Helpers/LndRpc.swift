//
//  LndRpc.swift
//  FullyNoded
//
//  Created by Peter Denton on 6/5/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

class LndRpc {
    
    static let sharedInstance = LndRpc()
    lazy var torClient = TorClient.sharedInstance
    
    private init() {}
    
    func makeLndCommand(command: LND_REST, completion: @escaping ((response: [String:Any]?, error: String?)) -> Void) {
        #if DEBUG
        print("makeLndCommand")
        #endif
        
        CoreDataService.retrieveEntity(entityName: .newNodes) { [weak self] nodes in
            guard let self = self else { return }
            
            guard let nodes = nodes, nodes.count > 0 else {
                completion((nil, "error getting nodes from core data"))
                return
            }
            
            var potentialLightningNode: [String:Any]?
                        
            for node in nodes {
                if let isLightning = node["isLightning"] as? Bool, isLightning {
                    if node["macaroon"] != nil {
                        potentialLightningNode = node
                    }
                }
            }
            
            guard let lightningNode = potentialLightningNode, let encryptedMacaroon = lightningNode["macaroon"] as? Data else {
                completion((nil, "No LND node."))
                return
            }
            
            let node = NodeStruct(dictionary: lightningNode)
            
            guard let encAddress = node.onionAddress else {
                completion((nil, "Error getting node address."))
                return
            }
            
            let onionAddress = decryptedValue(encAddress)
            let macaroonHex = decryptedValue(encryptedMacaroon)
            
            guard let url = URL(string: "https://\(onionAddress)/\(command.rawValue)") else {
                completion((nil, "error converting your url"))
                return
            }
            
            var request = URLRequest(url: url)
            request.addValue(macaroonHex, forHTTPHeaderField: "Grpc-Metadata-macaroon")
            
            #if DEBUG
            print("request: \(request)")
            #endif
            
            let task = self.torClient.session.dataTask(with: request as URLRequest) { (data, response, error) -> Void in
                guard let urlContent = data,
                      let json = try? JSONSerialization.jsonObject(with: urlContent, options: [.mutableContainers]) as? [String : Any] else {
                    
                    if let error = error {
                        #if DEBUG
                        print("lnd error: \(error.localizedDescription)")
                        #endif
                        
                        completion((nil, error.localizedDescription))
                        
                    } else if let httpResponse = response as? HTTPURLResponse {
                        switch httpResponse.statusCode {
                        case 401:
                            completion((nil, "Looks like your LND credentials are incorrect, please double check them."))
                        default:
                            completion((nil, "Unable to decode the response from your node, http status code: \(httpResponse.statusCode)"))
                        }
                        
                    } else {
                        completion((nil, "Unable to decode the response from your node..."))
                    }
                    
                    return
                }
                
                #if DEBUG
                print("lnd json: \(json)")
                #endif
                
                completion((json, nil))
            }
            
            task.resume()
        }
    }
}
