//
//  LocalRPC.swift
//  BitSense
//
//  Created by Peter on 30/06/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation
import UIKit

final class LocalRPCCall {
    
    static let sharedInstance = LocalRPCCall()
    let aes = AESService()
    let cd = CoreDataService()
    var rpcusername = ""
    var rpcpassword = ""
    var rpcport = ""
    var vc = UIViewController()
    var dictToReturn = NSDictionary()
    var doubleToReturn = Double()
    var arrayToReturn = NSArray()
    var stringToReturn = String()
    var errorBool = Bool()
    var errorDescription = String()
    
    func executeRPCCommand(method: BTC_CLI_COMMAND, param: Any, completion: @escaping () -> Void) {
        print("executeRPCCommand")
        
        let nodes = cd.retrieveCredentials()
        var activeNode = [String:Any]()
        
        for node in nodes {
            
            if (node["isActive"] as! Bool) {
                
                activeNode = node
                
            }
            
        }
        
        if activeNode["rpcuser"] != nil {
            
            rpcusername = aes.decryptKey(keyToDecrypt: activeNode["rpcuser"] as! String)
            print("username = \(rpcusername)")
            
        }
        
        if activeNode["rpcpassword"] != nil {
            
            rpcpassword = aes.decryptKey(keyToDecrypt: activeNode["rpcpassword"] as! String)
            print("password = \(rpcpassword)")
            
        }
        
        let url = URL(string: "http://user:password@127.0.0.1:18332")
        var request = URLRequest(url: url!)
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = "{\"jsonrpc\":\"1.0\",\"id\":\"curltest\",\"method\":\"\(method)\",\"params\":[\(param)]}".data(using: .utf8)
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            
            print("error = \(String(describing: error?.localizedDescription))")
            print("response = \(String(describing: response))")
            print("data = \(String(describing: data))")
            
            do {
                
                if error != nil {
                    
                    DispatchQueue.main.async {
                        
                        self.errorBool = true
                        self.errorDescription = error!.localizedDescription
                        completion()
                        print("error = \(error!.localizedDescription)")
                        
                    }
                    
                } else {
                    
                    if let urlContent = data {
                        
                        do {
                            
                            let jsonAddressResult = try JSONSerialization.jsonObject(with: urlContent, options: JSONSerialization.ReadingOptions.mutableLeaves) as! NSDictionary
                            
                            if let errorCheck = jsonAddressResult["error"] as? NSDictionary {
                                
                                DispatchQueue.main.async {
                                    
                                    if let errorMessage = errorCheck["message"] as? String {
                                        
                                        self.errorDescription = errorMessage
                                        print("error message = \(errorMessage)")
                                        
                                    } else {
                                        
                                        self.errorDescription = "Uknown error"
                                        
                                    }
                                    
                                    self.errorBool = true
                                    completion()
                                    
                                }
                                
                            } else {
                                
                                if let result = jsonAddressResult["result"] as? NSDictionary {
                                    
                                    self.dictToReturn = result
                                    self.errorBool = false
                                    completion()
                                    print("result = \(result)")
                                    
                                } else if let result = jsonAddressResult["result"] as? NSArray {
                                    
                                    self.arrayToReturn = result
                                    self.errorBool = false
                                    completion()
                                    print("result = \(result)")
                                    
                                } else if let result = jsonAddressResult["result"] as? Double {
                                    
                                    self.doubleToReturn = result
                                    self.errorBool = false
                                    completion()
                                    print("result = \(result)")
                                    
                                } else if let result = jsonAddressResult["result"] as? String {
                                    
                                    self.stringToReturn = result
                                    self.errorBool = false
                                    completion()
                                    print("result = \(result)")
                                    
                                }
                                
                            }
                            
                        } catch {
                            
                            self.errorBool = true
                            self.errorDescription = "Uknown Error"
                            completion()
                            print("unknown error")
                            
                        }
                        
                    }
                    
                }
                
            }
            
        }
        
        task.resume()
        
    }
    
    private init() {}
    
}
