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
    
    func command(_ command: LND_REST,
                        _ param: [String:Any]?,
                        _ urlExt: String?,
                        _ query: [String:Any]?,
                        completion: @escaping ((response: [String:Any]?, error: String?)) -> Void) {
        #if DEBUG
        print("lndCommand: \(command.rawValue) \(command.stringValue)")
        #endif
        
        CoreDataService.retrieveEntity(entityName: .newNodes) { [weak self] nodes in
            guard let self = self else { return }
            
            guard let nodes = nodes, nodes.count > 0 else {
                completion((nil, "error getting nodes from core data"))
                return
            }
            
            var potentialLightningNode: [String:Any]?
                        
            for node in nodes {
                if let isLightning = node["isLightning"] as? Bool, isLightning, let isActive = node["isActive"] as? Bool, isActive {
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
            
            if let encryptedCert = node.cert {
                guard let decryptedCert = Crypto.decrypt(encryptedCert) else {
                    completion((nil, "Error getting decrypting cert."))
                    return
                }
                
                self.torClient.cert = decryptedCert
            }
            
            guard let encAddress = node.onionAddress else {
                completion((nil, "Error getting node address."))
                return
            }
            
            let onionAddress = decryptedValue(encAddress)
            let macaroonHex = decryptedValue(encryptedMacaroon)
            var urlString = "https://\(onionAddress)/\(command.stringValue)"
            
            if let urlExt = urlExt {
                urlString += "/\(urlExt)"
            }
            
            guard var urlComponents = URLComponents(string: urlString) else { return }
            
            if let query = query {
                urlComponents.queryItems = []
                for (key, value) in query {
                    urlComponents.queryItems?.append(URLQueryItem(name: key, value: "\(value)"))
                }
            }
            
            guard let url = urlComponents.url else {
                completion((nil, "Error converting your url."))
                return
            }
            
            #if DEBUG
                print("url: \(url)")
            #endif
            
            var request = URLRequest(url: url)
            request.addValue(macaroonHex, forHTTPHeaderField: "Grpc-Metadata-macaroon")
            
            switch command {
            case .addinvoice,
                 .sendcoins,
                 .payinvoice,
                 .routepayment,
                 .connect,
                 .openchannel,
                 .fundingstep,
                 .fwdinghistory,
                 .keysend,
                 .getnewaddress:
                
                request.httpMethod = "POST"
                
                if command == .payinvoice, command == .connect {
                    request.timeoutInterval = 90
                }
                
                guard let param = param else { fallthrough }
                
                guard let jsonData = try? JSONSerialization.data(withJSONObject: param) else { return }
                
                #if DEBUG
                    print("LND param: \(param)")
                #endif
                
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("\(jsonData.count)", forHTTPHeaderField: "Content-Length")
                request.httpBody = jsonData
                
            case .closechannel, .disconnect:
                request.httpMethod = "DELETE"
                request.timeoutInterval = 90
                
//            case .getnewaddress:
//                request.httpMethod = "POST"
                
            default:
                request.httpMethod = "GET"
                
                #if DEBUG
                print("request: \(request)")
                #endif
            }
            
            let sesh = self.torClient.session
            
            let task = sesh.dataTask(with: request as URLRequest) { (data, response, error) -> Void in
                guard let urlContent = data,
                      let json = try? JSONSerialization.jsonObject(with: urlContent, options: [.mutableContainers]) as? [String : Any] else {
                    
                    if let error = error {
                        #if DEBUG
                        print("lnd error: \(error.localizedDescription)")
                        #endif
                        
                        completion((nil, error.localizedDescription))
                        
                    } else if let httpResponse = response as? HTTPURLResponse {
                        switch httpResponse.statusCode {
                        case 200:
                            completion((["success":true], nil))
                        case 401:
                            completion((nil, "Looks like your LND credentials are incorrect, please double check them."))
                        case 404:
                            completion((nil, "Command not found."))
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
