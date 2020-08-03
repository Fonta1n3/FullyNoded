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
    
    var rpcusername = ""
    var rpcpassword = ""
    var onionAddress = ""
    var rpcport = ""
    let torClient = TorClient.sharedInstance
    var attempts = 0
    
    private init() {}
    
    func command(method: String, param: Any, completion: @escaping ((response: Any?, errorDesc: String?)) -> Void) {
        attempts += 1
        
        //CoreDataService.retrieveEntity(entityName: .newNodes) { [unowned vc = self] nodes in
            
            //if nodes != nil {
                //var activeNode = [String:Any]()
                
//                for node in nodes! {
//                    if let isActive = node["isActive"] as? Bool {
//                        if isActive {
//                            activeNode = node
//                        }
//                    }
//                }
//
//                func decryptedValue(_ encryptedValue: Data) -> String {
//                    var decryptedValue = ""
//                    Crypto.decryptData(dataToDecrypt: encryptedValue) { decryptedData in
//                        if decryptedData != nil {
//                            decryptedValue = decryptedData!.utf8
//                        }
//                    }
//                    return decryptedValue
//                }
//
//                let node = NodeStruct(dictionary: activeNode)
//                if let encAddress = node.onionAddress {
//                    vc.onionAddress = decryptedValue(encAddress)
//                }
//                if let encUser = node.rpcuser {
//                    vc.rpcusername = decryptedValue(encUser)
//                }
//                if let encPassword = node.rpcpassword {
//                    vc.rpcpassword = decryptedValue(encPassword)
//                }
                
                //var walletUrl = "http://\(vc.rpcusername):\(vc.rpcpassword)@\(vc.onionAddress)"
        let lightningUrl = "http://lightning:kjsbc832b3bc8272ohd938h@7luqavfpkcdarq2c7wl4umlespbpgefgqmkpel6n7ystj3yjhmksobqd.onion:1312"
        //7luqavfpkcdarq2c7wl4umlespbpgefgqmkpel6n7ystj3yjhmksobqd.onion
                //let ud = UserDefaults.standard
                
//                if ud.object(forKey: "walletName") != nil {
//                    if let walletName = ud.object(forKey: "walletName") as? String {
//                        let b = isWalletRPC(command: method)
//                        if b {
//                            walletUrl += "/wallet/" + walletName
//                        }
//                    }
//                }
                
                //var formattedParam = (param as! String).replacingOccurrences(of: "''", with: "")
                //formattedParam = formattedParam.replacingOccurrences(of: "'\"'\"'", with: "'")
                
                guard let url = URL(string: lightningUrl) else {
                    completion((nil, "url error"))
                    return
                }
                
                var request = URLRequest(url: url)
//                var timeout = 10.0
//                if method == .gettxoutsetinfo {
//                    timeout = 500.0
//                }
//                if method == .importmulti || method == .deriveaddresses {
//                    timeout = 30.0
//                }
                //request.timeoutInterval = timeout
        //request.addValue("lightning", forHTTPHeaderField: "user")
        //request.addValue("kjsbc832b3bc8272ohd938h", forHTTPHeaderField: "password")
        let username = "lightning"
        let password = "kjsbc832b3bc8272ohd938h"
        let loginString = String(format: "%@:%@", username, password)
        let loginData = loginString.data(using: String.Encoding.utf8)!
        let base64LoginString = loginData.base64EncodedString()
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
                request.httpMethod = "POST"
                request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
                request.httpBody = "{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"\(method)\",\"params\":[\(param)]}".data(using: .utf8)
                
                #if DEBUG
                print("url = \(url)")
                print("request: \("{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"\(method)\",\"params\":[\(param)]}")")
                #endif
                
                let task = torClient.session.dataTask(with: request as URLRequest) { [unowned vc = self] (data, response, error) in
                    
                    do {
                        
                        if error != nil {
                            
                            if vc.attempts < 20 {
                                
                                vc.command(method: method, param: param, completion: completion)
                                
                            } else {
                                
                                vc.attempts = 0
                                #if DEBUG
                                print("error: \(error!.localizedDescription)")
                                #endif
                                completion((nil, error!.localizedDescription))
                                
                            }
                            
                        } else {
                            
                            if let urlContent = data {
                                
                                vc.attempts = 0
                                
                                print("data: \(data?.utf8)")
                                print("reponse: \(response)")
                                
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
                
//            } else {
//
//                completion((nil, "error getting nodes from core data"))
//
//            }
            
        //}
        
    }
}
