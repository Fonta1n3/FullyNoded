//
//  MakeRPCCall.swift
//  BitSense
//
//  Created by Peter on 31/03/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation
import UIKit

final class MakeRPCCall {
    
    static let sharedInstance = MakeRPCCall()
    let aes = AESService()
    let cd = CoreDataService()
    var rpcusername = ""
    var rpcpassword = ""
    var onionAddress = ""
    var rpcport = ""
    var vc = UIViewController()
    var dictToReturn = NSDictionary()
    var doubleToReturn = Double()
    var arrayToReturn = NSArray()
    var stringToReturn = String()
    var errorBool = Bool()
    var errorDescription = String()
    var torClient = TorClient.sharedInstance
    
    func executeRPCCommand(method: BTC_CLI_COMMAND, param: Any, completion: @escaping () -> Void) {
        print("executeRPCCommand")
        
        let nodes = cd.retrieveCredentials()
        var activeNode = [String:Any]()
        
        for node in nodes {
            
            if (node["isActive"] as! Bool) {
                
                activeNode = node
                
            }
            
        }
        
        if activeNode["onionAddress"] != nil {
            
            //onion V3 service needs to have similiar port setup in torrc file e.g. `8332 127.0.0.1:8332` not `8332 127.0.0.1:1234`
            onionAddress = aes.decryptKey(keyToDecrypt: activeNode["onionAddress"] as! String)
            
        }
        
        if activeNode["rpcuser"] != nil {
            
            rpcusername = aes.decryptKey(keyToDecrypt: activeNode["rpcuser"] as! String)
            
        }
        
        if activeNode["rpcpassword"] != nil {
            
            rpcpassword = aes.decryptKey(keyToDecrypt: activeNode["rpcpassword"] as! String)
            
        }
        
        var urlString = "http://\(rpcusername):\(rpcpassword)@\(onionAddress)"
        
        
        
        let userDefaults = UserDefaults.standard
        
        if userDefaults.object(forKey: "walletName") != nil {
            
            if let walletName = userDefaults.object(forKey: "walletName") as? String {
                
                let b = isWalletRPC(command: method)
                
                if b {
                    
                    urlString += "wallet/" + walletName
                    
                }
                
            }
            
        }
        
        let url = URL(string: urlString)
        print("TOR URL = \(String(describing: url))")
        var request = URLRequest(url: url!)
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = "{\"jsonrpc\":\"1.0\",\"id\":\"curltest\",\"method\":\"\(method)\",\"params\":[\(param)]}".data(using: .utf8)
        
        let task = torClient.session.dataTask(with: request) { (data, response, error) in
            
            print("error = \(String(describing: error?.localizedDescription))")
            print("response = \(String(describing: response))")
            print("data = \(String(describing: data))")
            
            do {
                
                if error != nil {
                    
                    DispatchQueue.main.async {
                        
                        self.errorBool = true
                        self.errorDescription = error!.localizedDescription
                        completion()
                        
                    }
                    
                } else {
                    
                    if let urlContent = data {
                        
                        do {
                            
                            let jsonAddressResult = try JSONSerialization.jsonObject(with: urlContent, options: JSONSerialization.ReadingOptions.mutableLeaves) as! NSDictionary
                            
                            if let errorCheck = jsonAddressResult["error"] as? NSDictionary {
                                
                                DispatchQueue.main.async {
                                    
                                    if let errorMessage = errorCheck["message"] as? String {
                                        
                                        self.errorDescription = errorMessage
                                        
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
