//
//  MakeRPCCall.swift
//  BitSense
//
//  Created by Peter on 31/03/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

enum MakeRPCCallError: Error {
    case description(String)
}

class MakeRPCCall {
    
    static let sharedInstance = MakeRPCCall()
    
    var rpcusername = ""
    var rpcpassword = ""
    var onionAddress = ""
    var rpcport = ""
    let torClient = TorClient.sharedInstance
    var attempts = 0
    
    private init() {}
    
    func executeRPCCommand(method: BTC_CLI_COMMAND, param: Any, completion: @escaping ((response: Any?, errorDesc: String?)) -> Void) {
        attempts += 1
        
        CoreDataService.retrieveEntity(entityName: .newNodes) { [unowned vc = self] nodes in
            
            if nodes != nil {
                var activeNode = [String:Any]()
                
                for node in nodes! {
                    if let isActive = node["isActive"] as? Bool {
                        if isActive {
                            activeNode = node
                        }
                    }
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
                
                let node = NodeStruct(dictionary: activeNode)
                if let encAddress = node.onionAddress {
                    vc.onionAddress = decryptedValue(encAddress)
                }
                if let encUser = node.rpcuser {
                    vc.rpcusername = decryptedValue(encUser)
                }
                if let encPassword = node.rpcpassword {
                    vc.rpcpassword = decryptedValue(encPassword)
                }
                
                var walletUrl = "http://\(vc.rpcusername):\(vc.rpcpassword)@\(vc.onionAddress)"
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
                if method == .gettxoutsetinfo {
                    timeout = 1000.0
                }
                if method == .importmulti || method == .deriveaddresses {
                    timeout = 60.0
                }
                request.timeoutInterval = timeout
                request.httpMethod = "POST"
                request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
                request.httpBody = "{\"jsonrpc\":\"1.0\",\"id\":\"curltest\",\"method\":\"\(method.rawValue)\",\"params\":[\(formattedParam)]}".data(using: .utf8)
                
                #if DEBUG
                print("url = \(url)")
                print("request: \("{\"jsonrpc\":\"1.0\",\"id\":\"curltest\",\"method\":\"\(method.rawValue)\",\"params\":[\(formattedParam)]}")")
                #endif
                
                var sesh = URLSession(configuration: .default)
                if vc.onionAddress.contains("onion") {
                    sesh = vc.torClient.session
                }
                
                let task = sesh.dataTask(with: request as URLRequest) { [unowned vc = self] (data, response, error) in
                    
                    do {
                        
                        if error != nil {
                            
                            if vc.attempts < 20 {
                                
                                vc.executeRPCCommand(method: method, param: param, completion: completion)
                                
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
    
    // TODO: Clean up.
    func executeCommand(method: BTC_CLI_COMMAND, param: String = "", completion: @escaping (Result<Data, MakeRPCCallError>) -> Void) {
        CoreDataService.retrieveEntity(entityName: .newNodes) { [weak self] nodes in
            guard let self = self else { return }

            guard let nodes = nodes else {
                completion(.failure(.description("Error getting nodes from core data")))
                return
            }

            var activeNode = [String:Any]()

            for node in nodes {
                if let isActive = node["isActive"] as? Bool {
                    if isActive {
                        activeNode = node
                    }
                }
            }

            // FIXME: Race condition possible as Crypto.decryptData(dataToDecrypt: has an escaping closure
            func decryptedValue(_ encryptedValue: Data) -> String {
                var decryptedValue = ""
                Crypto.decryptData(dataToDecrypt: encryptedValue) { decryptedData in
                    if decryptedData != nil {
                        decryptedValue = decryptedData!.utf8
                    }
                }
                return decryptedValue
            }

            let node = NodeStruct(dictionary: activeNode)
            if let encAddress = node.onionAddress {
                self.onionAddress = decryptedValue(encAddress)
            }
            if let encUser = node.rpcuser {
                self.rpcusername = decryptedValue(encUser)
            }
            if let encPassword = node.rpcpassword {
                self.rpcpassword = decryptedValue(encPassword)
            }

            var walletUrl = "http://\(self.rpcusername):\(self.rpcpassword)@\(self.onionAddress)"
            let ud = UserDefaults.standard

            if ud.object(forKey: "walletName") != nil {
                if let walletName = ud.object(forKey: "walletName") as? String {
                    let b = isWalletRPC(command: method)
                    if b {
                        walletUrl += "/wallet/" + walletName
                    }
                }
            }

            let formattedParam = param.replacingOccurrences(of: "''", with: "")
                                      .replacingOccurrences(of: "'\"'\"'", with: "'")

            guard let url = URL(string: walletUrl) else {
                completion(.failure(.description("url error")))
                return
            }

            var request = URLRequest(url: url)
            var timeout = 10.0
            if method == .gettxoutsetinfo {
                timeout = 1000.0
            }
            if method == .importmulti || method == .deriveaddresses {
                timeout = 60.0
            }
            
            let httpBody = "{\"jsonrpc\":\"1.0\",\"id\":\"curltest\",\"method\":\"\(method.rawValue)\",\"params\":[\(formattedParam)]}"
            request.timeoutInterval = timeout
            request.httpMethod = "POST"
            request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
            request.httpBody = httpBody.data(using: .utf8)

            #if DEBUG
            print("url = \(url)")
            print(httpBody)
            #endif

            var sesh = URLSession(configuration: .default)
            if self.onionAddress.contains("onion") { // TODO: Ask Fontaine
                sesh = self.torClient.session
            }

            let task = sesh.dataTask(with: request as URLRequest) { (data, response, error) in

                guard error == nil else {
                    #if DEBUG
                    print("error: \(error!)")
                    #endif
                    completion(.failure(.description("\(error!)")))
                    return
                }

                guard let data = data else {
                    completion(.failure(.description("Data is nil")))
                    return
                }

                completion(.success(data))

            }

            task.resume()

        }
        
    }
    
}



