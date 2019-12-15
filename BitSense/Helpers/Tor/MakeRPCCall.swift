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
    let aes = AESService()
    let cd = CoreDataService()
    var rpcusername = ""
    var rpcpassword = ""
    var onionAddress = ""
    var rpcport = ""
    var errorBool = Bool()
    var errorDescription = String()
    let torClient = TorClient.sharedInstance
    var objectToReturn:Any!
    
    func executeRPCCommand(method: BTC_CLI_COMMAND, param: Any, completion: @escaping () -> Void) {
        print("executeTorRPCCommand")
        
        cd.retrieveEntity(entityName: .nodes) {
            
            if !self.cd.errorBool {
                
                let nodes = self.cd.entities
                var activeNode = [String:Any]()
                
                for node in nodes {
                    
                    if let b = node["isActive"] as? Bool {
                        
                        if b {
                            
                            activeNode = node
                            
                        }
                        
                    }
                    
                }
                
                let node = NodeStruct(dictionary: activeNode)
                self.onionAddress = self.aes.decryptKey(keyToDecrypt: node.onionAddress)
                self.rpcusername = self.aes.decryptKey(keyToDecrypt: node.rpcuser)
                self.rpcpassword = self.aes.decryptKey(keyToDecrypt: node.rpcpassword)
                
                var walletUrl = "http://\(self.rpcusername):\(self.rpcpassword)@\(self.onionAddress)"
                print("walleturl = \(walletUrl)")
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
                    self.errorBool = true
                    self.errorDescription = "url error"
                    completion()
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
                print("request: \("{\"jsonrpc\":\"1.0\",\"id\":\"curltest\",\"method\":\"\(method)\",\"params\":[\(formattedParam)]}")")
                request.httpBody = "{\"jsonrpc\":\"1.0\",\"id\":\"curltest\",\"method\":\"\(method)\",\"params\":[\(formattedParam)]}".data(using: .utf8)
                
                let queue = DispatchQueue(label: "com.FullyNoded.torQueue")
                queue.async {
                    
                    let task = self.torClient.session.dataTask(with: request as URLRequest) { (data, response, error) in
                        
                        do {
                            
                            if error != nil {
                                
                                self.errorBool = true
                                self.errorDescription = error!.localizedDescription
                                completion()
                                
                            } else {
                                
                                if let urlContent = data {
                                    
                                    do {
                                        
                                        let jsonAddressResult = try JSONSerialization.jsonObject(with: urlContent, options: JSONSerialization.ReadingOptions.mutableLeaves) as! NSDictionary
                                        
                                        if let errorCheck = jsonAddressResult["error"] as? NSDictionary {
                                            
                                                if let errorMessage = errorCheck["message"] as? String {
                                                    
                                                    self.errorDescription = errorMessage
                                                    
                                                } else {
                                                    
                                                    self.errorDescription = "Uknown error"
                                                    
                                                }
                                                
                                                self.errorBool = true
                                                completion()
                                                
                                            
                                        } else {
                                            
                                            self.errorBool = false
                                            self.errorDescription = ""
                                            self.objectToReturn = jsonAddressResult["result"]
                                            completion()
                                            
                                        }
                                        
                                    } catch {
                                        
                                        self.errorBool = true
                                        self.errorDescription = "Uknown Error"
                                        completion()
                                        
                                    }
                                    
                                }
                                
                            }
                            
                        }
                    
                    }
                    
                    task.resume()
                    
                }
                
            } else {
                
                self.errorBool = true
                self.errorDescription = "error getting nodes from core data"
                completion()
                
            }
            
        }
        
    }
    
    private init() {}
    
}
