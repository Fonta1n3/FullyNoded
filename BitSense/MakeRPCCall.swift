//
//  MakeRPCCall.swift
//  BitSense
//
//  Created by Peter on 31/03/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation
import SwiftKeychainWrapper
import AES256CBC

final class MakeRPCCall {
    
    static let sharedInstance = MakeRPCCall()
    var nodeUsername = ""
    var nodePassword = ""
    var ip = ""
    var port = ""
    var credentialsComplete = Bool()
    let userDefaults = UserDefaults.standard
    var vc = UIViewController()
    var dictToReturn = NSDictionary()
    var doubleToReturn = Double()
    var arrayToReturn = NSArray()
    var stringToReturn = String()
    var errorBool = Bool()
    var errorDescription = String()
    
    func decrypt(item: String) -> String {
        
        var decrypted = ""
        
        if let password = KeychainWrapper.standard.string(forKey: "AESPassword") {
            
            if let decryptedCheck = AES256CBC.decryptString(item, password: password) {
                
                decrypted = decryptedCheck
                
            }
            
        }
        
        return decrypted
        
    }
    
    func encryptKey(keyToEncrypt: String) -> String {
        
        let password = KeychainWrapper.standard.string(forKey: "AESPassword")!
        
        let encryptedkey = AES256CBC.encryptString(keyToEncrypt, password: password)!
        
        return encryptedkey
        
    }
    
    func savePassword(password: String) {
        
        let stringToSave = self.encryptKey(keyToEncrypt: password)
        userDefaults.set(stringToSave, forKey: "NodePassword")
        
    }
    
    func saveIPAdress(ipAddress: String) {
        
        let stringToSave = self.encryptKey(keyToEncrypt: ipAddress)
        userDefaults.set(stringToSave, forKey: "NodeIPAddress")
        
    }
    
    func savePort(port: String) {
        
        let stringToSave = self.encryptKey(keyToEncrypt: port)
        userDefaults.set(stringToSave, forKey: "NodePort")
    }
    
    func saveUsername(username: String) {
        
        let stringToSave = self.encryptKey(keyToEncrypt: username)
        userDefaults.set(stringToSave, forKey: "NodeUsername")
        
    }
    
    func executeRPCCommand(method: BTC_CLI_COMMAND, param: Any, completion: @escaping () -> Void) {
        print("executeNodeCommand")
        
        if userDefaults.string(forKey: "NodeUsername") != nil {
            
            nodeUsername = decrypt(item: userDefaults.string(forKey: "NodeUsername")!)
            credentialsComplete = true
            
        } else {
            
            credentialsComplete = false
        }
        
        if userDefaults.string(forKey: "NodePassword") != nil {
            
            nodePassword = decrypt(item: userDefaults.string(forKey: "NodePassword")!)
            credentialsComplete = true
            
        } else {
            
            credentialsComplete = false
        }
        
        if userDefaults.string(forKey: "NodeIPAddress") != nil {
            
            ip = decrypt(item: userDefaults.string(forKey: "NodeIPAddress")!)
            credentialsComplete = true
            
        } else {
            
            credentialsComplete = false
        }
        
        if userDefaults.string(forKey: "NodePort") != nil {
            
            port = decrypt(item: userDefaults.string(forKey: "NodePort")!)
            credentialsComplete = true
            
        } else {
            
            credentialsComplete = false
        }
        
        if !credentialsComplete {
            
            port = "18332"
            ip = "46.101.239.249"
            nodeUsername = "bitcoin"
            nodePassword = "password"
            
            savePort(port: port)
            saveIPAdress(ipAddress: ip)
            saveUsername(username: nodeUsername)
            savePassword(password: nodePassword)
            
            displayAlert(viewController: vc, title: "Alert", message: "Looks like you have not logged in to your own node yet or incorrectly filled out your credentials, you are connected to our testnet full node so you can play with the app before connecting to your own.\n\nTo connect to your own node tap the settings button and \"Log in to your own node\".\n\nIf you have any issues please email me at bitsenseapp@gmail.com"
            )
            
        }
        
        print("port = \(port)")
        print("username = \(nodeUsername)")
        print("password = \(nodePassword)")
        print("ip = \(ip)")
        
        let url = URL(string: "http://\(nodeUsername):\(nodePassword)@\(ip):\(port)")
        var request = URLRequest(url: url!)
        request.timeoutInterval = 5
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = "{\"jsonrpc\":\"1.0\",\"id\":\"curltest\",\"method\":\"\(method.rawValue)\",\"params\":[\(param)]}".data(using: .utf8)
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) -> Void in
            
            do {
                
                if error != nil {
                    
                    DispatchQueue.main.async {
                        
                        print("error = \(error.debugDescription)")
                        self.errorBool = true
                        self.errorDescription = "Unable to connect via RPC, please go to settings and enable SSH to try to connect via SSH"
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
