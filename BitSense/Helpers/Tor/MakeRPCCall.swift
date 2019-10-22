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
        
        let nodes = cd.retrieveEntity(entityName: .nodes)
        var activeNode = [String:Any]()
        
        for node in nodes {
            
            if (node["isActive"] as! Bool) {
                
                activeNode = node
                
            }
            
        }
        
        let node = NodeStruct(dictionary: activeNode)
        
        if node.onionAddress != "" {
            
            onionAddress = aes.decryptKey(keyToDecrypt: node.onionAddress)
            
        }
        
        if node.rpcuser != "" {
            
            rpcusername = aes.decryptKey(keyToDecrypt: node.rpcuser)
            
        }
        
        if node.rpcpassword != "" {
            
            rpcpassword = aes.decryptKey(keyToDecrypt: node.rpcpassword)
            
            
        }
        
        var walletUrl = "http://\(rpcusername):\(rpcpassword)@\(onionAddress)"
        let ud = UserDefaults.standard
        
        if ud.object(forKey: "walletName") != nil {

            if let walletName = ud.object(forKey: "walletName") as? String {

                let b = isWalletRPC(command: method)

                if b {

                    walletUrl += "/wallet/" + walletName
                    print("walleturl = \(walletUrl)")

                }

            }

        }
        
        var formattedParam = (param as! String).replacingOccurrences(of: "''", with: "")
        formattedParam = formattedParam.replacingOccurrences(of: "'\"'\"'", with: "'")
        
        let url = URL(string: walletUrl)
        print("url = \(String(describing: url))")
        
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
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
        
    }
    
    private init() {}
    
}
