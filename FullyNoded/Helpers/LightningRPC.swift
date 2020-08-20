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
    class func command(method: LIGHTNING_CLI, param: Any, completion: @escaping ((response: Any?, errorDesc: String?)) -> Void) {
        
        var rpcusername = ""
        var rpcpassword = ""
        var onionAddress = ""
        
        CoreDataService.retrieveEntity(entityName: .newNodes) { nodes in
            if nodes != nil {
                var lightningNode:[String:Any]?
                
                for node in nodes! {
                    if let isLightning = node["isLightning"] as? Bool {
                        if isLightning {
                            lightningNode = node
                        }
                    }
                }
                
                guard lightningNode != nil else {
                    completion((nil, "no lightning node"))
                    return
                }
                
                func decryptedValue(_ encryptedValue: Data) -> String {
                    var decryptedValue = ""
                    Crypto.decryptData(dataToDecrypt: encryptedValue) { decryptedData in
                        if decryptedData != nil {
                            decryptedValue = decryptedData!.utf8
                        }
                    }
                    return decryptedValue
                }
                
                let node = NodeStruct(dictionary: lightningNode!)
                
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
                    completion((nil, "url error"))
                    return
                }
                
                var request = URLRequest(url: url)
                let id = UUID()
                let loginString = String(format: "%@:%@", rpcusername, rpcpassword)
                let loginData = loginString.data(using: String.Encoding.utf8)!
                let base64LoginString = loginData.base64EncodedString()
                request.timeoutInterval = 5
                request.addValue("application/json", forHTTPHeaderField: "Accept")
                request.addValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
                request.httpMethod = "POST"
                request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
                request.httpBody = "{\"jsonrpc\":\"2.0\",\"id\":\"\(id)\",\"method\":\"\(method.rawValue)\",\"params\":[\(param)]}".data(using: .utf8)
                
                #if DEBUG
                print("url = \(url)")
                print("request: \("{\"jsonrpc\":\"2.0\",\"id\":\"\(id)\",\"method\":\"\(method.rawValue)\",\"params\":[\(param)]}")")
                #endif
                
                let task = torClient.session.dataTask(with: request as URLRequest) { (data, response, error) in
                    
                    do {
                        
                        if error != nil {
                            
                            if self.attempts < 10 {
                                self.attempts += 1
                                command(method: method, param: param, completion: completion)
                            } else {
                                self.attempts = 0
                                #if DEBUG
                                print("error: \(error!.localizedDescription)")
                                #endif
                                completion((nil, error!.localizedDescription))
                            }
                                                        
                        } else {
                            
                            if let urlContent = data {
                                
                                do {
                                    let jsonAddressResult = try JSONSerialization.jsonObject(with: urlContent, options: JSONSerialization.ReadingOptions.mutableLeaves) as! NSDictionary
                                    
                                    #if DEBUG
                                    print("json: \(jsonAddressResult)")
                                    #endif
                                    
                                    if let errorCheck = jsonAddressResult["error"] as? NSDictionary {
                                        var errorDesc = ""
                                        
                                        if let errorMessage = errorCheck["message"] as? String {
                                            errorDesc = errorMessage
                                            
                                        } else {
                                            errorDesc = "Uknown error"
                                            
                                        }
                                        
                                        completion((nil, errorDesc))
                                        
                                    } else {
                                        completion((jsonAddressResult["result"], nil))
                                        
                                    }
                                    
                                } catch {
                                    completion((nil, "unknown error"))
                                    
                                }
                            }
                        }
                    }
                }
                task.resume()
                
            } else {
                completion((nil, "error getting nodes from core data"))
                
            }
        }
    }
    
}
