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
    
    private init() {}
    
    func executeRPCCommand(method: BTC_CLI_COMMAND, param: Any, completion: @escaping ((response: Any?, errorDesc: String?)) -> Void) {
        attempts += 1
        
        CoreDataService.retrieveEntity(entityName: .newNodes) { [weak self] nodes in
            guard let self = self else { return }
            
            guard let nodes = nodes, nodes.count > 0 else {
                completion((nil, "error getting nodes from core data"))
                return
            }
            
            var activeNode: [String:Any]?
            
            for node in nodes {
                if let isActive = node["isActive"] as? Bool, let isLightning = node["isLightning"] as? Bool, !isLightning {
                    if isActive {
                        activeNode = node
                    }
                }
            }
            
            guard let active = activeNode else {
                completion((nil, "no active nodes!"))
                return
            }
            
            let node = NodeStruct(dictionary: active)
            
            guard let encAddress = node.onionAddress, let encUser = node.rpcuser, let encPassword = node.rpcpassword else {
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
            
            var formattedParam = (param as! String).replacingOccurrences(of: "''", with: "")
            formattedParam = formattedParam.replacingOccurrences(of: "'\"'\"'", with: "'")
            
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
            let id = UUID()
            
            request.timeoutInterval = timeout
            request.httpMethod = "POST"
            request.addValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
            request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
            request.httpBody = "{\"jsonrpc\":\"1.0\",\"id\":\"\(id)\",\"method\":\"\(method.rawValue)\",\"params\":[\(formattedParam)]}".data(using: .utf8)
            
            #if DEBUG
            print("url = \(url)")
            print("request: \("{\"jsonrpc\":\"1.0\",\"id\":\"\(id)\",\"method\":\"\(method.rawValue)\",\"params\":[\(formattedParam)]}")")
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
                            self.executeRPCCommand(method: method, param: param, completion: completion)
                        } else {
                            self.attempts = 0
                            completion((nil, "Unknown error, ran out of attempts"))
                        }
                        
                        return
                    }
                    
                    if self.attempts < 20 {
                        self.executeRPCCommand(method: method, param: param, completion: completion)
                    } else {
                        self.attempts = 0
                        #if DEBUG
                        print("error: \(error.localizedDescription)")
                        #endif
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
    }
}



