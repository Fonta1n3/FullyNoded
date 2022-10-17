//
//  JMRPC.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/20/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

class JMRPC {
    
    static let sharedInstance = JMRPC()
    let torClient = TorClient.sharedInstance
    private var attempts = 0
    
    private init() {}
    
    func command(method: JM_REST, param: [String:Any]?, completion: @escaping ((response: Any?, errorDesc: String?)) -> Void) {
        attempts += 1
        
        CoreDataService.retrieveEntity(entityName: .newNodes) { [weak self] nodes in
            guard let self = self else { return }
            
            guard let nodes = nodes, nodes.count > 0 else {
                completion((nil, "error getting nodes from core data"))
                return
            }
            
            var activeNode: [String:Any]?
            
            for node in nodes {
                if let isActive = node["isActive"] as? Bool,
                   let isLightning = node["isLightning"] as? Bool,
                   !isLightning,
                   let isJoinMarket = node["isJoinMarket"] as? Bool,
                   isJoinMarket {
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
            
            guard let encAddress = node.onionAddress else {
                completion((nil, "error getting encrypted node credentials"))
                return
            }
            
            if let encryptedCert = node.cert {
                guard let decryptedCert = Crypto.decrypt(encryptedCert) else {
                    completion((nil, "Error getting decrypting cert."))
                    return
                }
                
                self.torClient.cert = decryptedCert.base64EncodedData()
            }
            
            let onionAddress = decryptedValue(encAddress)
            
            guard onionAddress != "" else {
                completion((nil, "error decrypting node credentials"))
                return
            }
            
            let walletUrl = "https://\(onionAddress)/\(method.stringValue)"
                        
             guard let url = URL(string: walletUrl) else {
                completion((nil, "url error"))
                return
            }
            
            var request = URLRequest(url: url)
            var timeout = 10.0
            
            var sesh = URLSession(configuration: .default)
            
            if onionAddress.contains("onion") {
                sesh = self.torClient.session
            }
            
            var httpMethod:String!
            
            switch method {
            case .walletall,
                    .session:
                httpMethod = "GET"
                
            case .lockwallet(let wallet),
                    .walletdisplay(let wallet),
                    .getaddress(jmWallet: let wallet),
                    .makerStop(jmWallet: let wallet),
                    .takerStop(jmWallet: let wallet),
                    .getSeed(jmWallet: let wallet),
                    .listutxos(jmWallet: let wallet):
                httpMethod = "GET"
                
                guard let decryptedToken = Crypto.decrypt(wallet.token),
                      let token = decryptedToken.utf8String else {
                          completion((nil, "Unable to decrypt token."))
                          return
                      }
                
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                
            case .unlockwallet(jmWallet: let wallet):
                httpMethod = "POST"
                
                guard let decryptedPassword = Crypto.decrypt(wallet.password),
                      let password = decryptedPassword.utf8String else {
                          completion((nil, "Unable to decrypt password."))
                          return
                      }
                                
                guard let jsonData = try? JSONSerialization.data(withJSONObject: ["password":password]) else { return }
                
                #if DEBUG
                print("JM param: \(String(describing: param))")
                #endif
                
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("\(jsonData.count)", forHTTPHeaderField: "Content-Length")
                request.httpBody = jsonData
                
            case .walletcreate:
                httpMethod = "POST"
                timeout = 1000
                
            case .coinjoin(jmWallet: let wallet),
                    .makerStart(jmWallet: let wallet),
                    .configGet(jmWallet: let wallet),
                    .configSet(jmWallet: let wallet),
                    .unfreeze(jmWallet: let wallet),
                    .directSend(jmWallet: let wallet):
                
                httpMethod = "POST"
                
                guard let decryptedToken = Crypto.decrypt(wallet.token),
                      let token = decryptedToken.utf8String else {
                          completion((nil, "Unable to decrypt token."))
                          return
                      }
                
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                
            case .gettimelockaddress(jmWallet: let wallet, date: _):
                httpMethod = "GET"
                
                guard let decryptedToken = Crypto.decrypt(wallet.token),
                      let token = decryptedToken.utf8String else {
                          completion((nil, "Unable to decrypt token."))
                          return
                      }
                
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            if let param = param {
                #if DEBUG
                print("JM param: \(param)")
                #endif
                
                guard let jsonData = try? JSONSerialization.data(withJSONObject: param) else {
                    completion((nil, "Unable to encode your params into json data."))
                    return
                }
                
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("\(jsonData.count)", forHTTPHeaderField: "Content-Length")
                request.httpBody = jsonData
                
            } else {
                request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
            }
            
            request.timeoutInterval = timeout
            request.httpMethod = httpMethod
            request.url = url
            
            #if DEBUG
            print("url = \(url)")
            #endif
                        
            let task = sesh.dataTask(with: request as URLRequest) { [weak self] (data, response, error) in
                guard let self = self else { return }
                                
                guard let urlContent = data else {
                    
                    guard let error = error else {
                        if self.attempts < 20 {
                            self.command(method: method, param: param, completion: completion)
                        } else {
                            self.attempts = 0
                            completion((nil, "Unknown error, ran out of attempts"))
                        }
                        
                        return
                    }
                    
                    if self.attempts < 20 {
                        self.command(method: method, param: param, completion: completion)
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
                
                guard var message = json["message"] as? String else {
                    completion((json, nil))
                    return
                }
                
                if message == "Invalid credentials." {
                    // should be able to auto unlock here...
                    message = "Invalid token, you need to restart your jm daemon and try again."
                }
                
                completion((nil, message))
            }
            
            task.resume()
        }
    }
}
