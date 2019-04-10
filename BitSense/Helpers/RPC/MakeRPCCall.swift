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
    let aes = AESService.sharedInstance
    let cd = CoreDataService.sharedInstance
    var nodeUsername = ""
    var nodePassword = ""
    var ip = ""
    var port = ""
    var credentialsComplete = Bool()
    var vc = UIViewController()
    var dictToReturn = NSDictionary()
    var doubleToReturn = Double()
    var arrayToReturn = NSArray()
    var stringToReturn = String()
    var errorBool = Bool()
    var errorDescription = String()
    
    func executeRPCCommand(method: BTC_CLI_COMMAND, param: Any, completion: @escaping () -> Void) {
        print("executeNodeCommand")
        
        let nodes = cd.retrieveCredentials()
        var activeNode = [String:Any]()
        
        for node in nodes {
            
            if (node["isActive"] as! Bool) {
             
                activeNode = node
                
            }
            
        }
        
        if activeNode["port"] != nil {
            
            port = aes.decryptKey(keyToDecrypt: activeNode["port"] as! String)
            credentialsComplete = true
            
        } else {
            
            credentialsComplete = false
            
        }
        
        if activeNode["ip"] != nil {
            
            ip = aes.decryptKey(keyToDecrypt: activeNode["ip"] as! String)
            credentialsComplete = true
            
        } else {
            
            credentialsComplete = false
            
        }
        
        if activeNode["username"] != nil {
            
            nodeUsername = aes.decryptKey(keyToDecrypt: activeNode["username"] as! String)
            credentialsComplete = true
            
        } else {
            
            credentialsComplete = false
            
        }
        
        if activeNode["password"] != nil {
            
            nodePassword = aes.decryptKey(keyToDecrypt: activeNode["password"] as! String)
            credentialsComplete = true
            
        } else {
            
            credentialsComplete = false
            
        }
        
        if !credentialsComplete {
            
            port = "18332"
            ip = "46.101.239.249"
            nodeUsername = "bitcoin"
            nodePassword = "password"
            
            displayAlert(viewController: vc, title: "Alert", message: "Looks like you have not logged in to your own node yet or incorrectly filled out your credentials, you are connected to our testnet full node so you can play with the app before connecting to your own.\n\nTo connect to your own node tap the settings button and \"Log in to your own node\".\n\nIf you have any issues please email me at bitsenseapp@gmail.com"
            )
            
        }
        
        print("port = \(port)")
        print("username = \(nodeUsername)")
        print("password = \(nodePassword)")
        print("ip = \(ip)")
        
        let url = URL(string: "http://\(nodeUsername):\(nodePassword)@\(ip):\(port)")
        var request = URLRequest(url: url!)
        //request.timeoutInterval = 30
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = "{\"jsonrpc\":\"1.0\",\"id\":\"curltest\",\"method\":\"\(method.rawValue)\",\"params\":[\(param)]}".data(using: .utf8)
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) -> Void in
            
            do {
                
                if error != nil {
                    
                    DispatchQueue.main.async {
                        
                        print("error = \(error.debugDescription)")
                        self.errorBool = true
                        self.errorDescription = error!.localizedDescription
                        completion()
                        
                    }
                    
                } else {
                    
                    if let urlContent = data {
                        
                        do {
                            
                            let jsonAddressResult = try JSONSerialization.jsonObject(with: urlContent, options: JSONSerialization.ReadingOptions.mutableLeaves) as! NSDictionary
                            
                            print("jsonAddressResult = \(jsonAddressResult)")
                            
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
                                    
                                } else if let result = jsonAddressResult["result"] as? NSArray {
                                    
                                    self.arrayToReturn = result
                                    self.errorBool = false
                                    completion()
                                    
                                } else if let result = jsonAddressResult["result"] as? Double {
                                    
                                    self.doubleToReturn = result
                                    self.errorBool = false
                                    completion()
                                    
                                } else if let result = jsonAddressResult["result"] as? String {
                                    
                                    self.stringToReturn = result
                                    self.errorBool = false
                                    completion()
                                    
                                }
                                
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
    
    private init() {
        
        
        
    }
    
}
