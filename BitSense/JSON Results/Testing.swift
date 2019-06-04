//
//  Testing.swift
//  BitSense
//
//  Created by Peter on 24/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class Tests {
    
    func listTransactions() -> NSArray {
        
        var arrayToReturn = NSArray()
        
        if let path = Bundle.main.path(forResource: "ListTransactions", ofType: "json") {
            
            do {
                
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
                
                let jsonResult = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableLeaves) as! NSDictionary
                
                arrayToReturn = jsonResult["result"] as! NSArray
                
                print("jsonResult = \(String(describing: arrayToReturn))")
                
            } catch {
                
                print("error")
                
            }
            
        } else {
            
            print("wrong path")
        }
        
        return arrayToReturn
        
    }
    
    func getBalance() -> Double {
        
        var doubleToReturn = Double()
        
        if let path = Bundle.main.path(forResource: "GetBalance", ofType: "json") {
            
            do {
                
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
                
                let jsonResult = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableLeaves) as! NSDictionary
                
                doubleToReturn = jsonResult["result"] as! Double
                
                print("jsonResult = \(String(describing: doubleToReturn))")
                
            } catch {
                
                print("error")
                
            }
            
        } else {
            
            print("wrong path")
        }
        
        return doubleToReturn
        
    }
    
    func getUnconfirmedBalance() -> Double {
        
        var doubleToReturn = Double()
        
        if let path = Bundle.main.path(forResource: "GetUnconfirmedBalance", ofType: "json") {
            
            do {
                
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
                
                let jsonResult = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableLeaves) as! NSDictionary
                
                doubleToReturn = jsonResult["result"] as! Double
                
                print("jsonResult = \(String(describing: doubleToReturn))")
                
            } catch {
                
                print("error")
                
            }
            
        } else {
            
            print("wrong path")
        }
        
        return doubleToReturn
        
    }
    
    func getNetworkInfo() -> NSDictionary {
        
        var dictToReturn = NSDictionary()
        
        if let path = Bundle.main.path(forResource: "GetNetworkInfo", ofType: "json") {
            
            do {
                
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
                
                let jsonResult = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableLeaves) as! NSDictionary
                
                dictToReturn = jsonResult["result"] as! NSDictionary
                
                print("jsonResult = \(String(describing: dictToReturn))")
                
            } catch {
                
                print("error")
                
            }
            
        } else {
            
            print("wrong path")
        }
        
        return dictToReturn
        
    }
    
    func getBlockchainInfo() -> NSDictionary {
        
        var dictToReturn = NSDictionary()
        
        if let path = Bundle.main.path(forResource: "GetBlockchainInfo", ofType: "json") {
            
            do {
                
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
                
                let jsonResult = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableLeaves) as! NSDictionary
                
                dictToReturn = jsonResult["result"] as! NSDictionary
                
                print("jsonResult = \(String(describing: dictToReturn))")
                
            } catch {
                
                print("error")
                
            }
            
        } else {
            
            print("wrong path")
        }
        
        return dictToReturn
        
    }
    
    func getMiningInfo() -> NSDictionary {
        
        var dictToReturn = NSDictionary()
        
        if let path = Bundle.main.path(forResource: "GetMiningInfo", ofType: "json") {
            
            do {
                
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
                
                let jsonResult = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableLeaves) as! NSDictionary
                
                dictToReturn = jsonResult["result"] as! NSDictionary
                
                print("jsonResult = \(String(describing: dictToReturn))")
                
            } catch {
                
                print("error")
                
            }
            
        } else {
            
            print("wrong path")
        }
        
        return dictToReturn
        
    }
    
    func getUnspent() -> NSArray {
        
        var arrayToReturn = NSArray()
        
        if let path = Bundle.main.path(forResource: "ListUnspent", ofType: "json") {
            
            do {
                
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
                
                let jsonResult = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableLeaves) as! NSDictionary
                
                arrayToReturn = jsonResult["result"] as! NSArray
                
                print("jsonResult = \(String(describing: arrayToReturn))")
                
            } catch {
                
                print("error")
                
            }
            
        } else {
            
            print("wrong path")
        }
        
        return arrayToReturn
        
    }
    
    func getPeerInfo() -> NSArray {
        
        var arrayToReturn = NSArray()
        
        if let path = Bundle.main.path(forResource: "GetPeerInfo", ofType: "json") {
            
            do {
                
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
                
                let jsonResult = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableLeaves) as! NSDictionary
                
                arrayToReturn = jsonResult["result"] as! NSArray
                
                print("jsonResult = \(String(describing: arrayToReturn))")
                
            } catch {
                
                print("error")
                
            }
            
        } else {
            
            print("wrong path")
        }
        
        return arrayToReturn
        
    }
    
    func signedRaw() -> String {
        
        return "0200000001ec0155a8cb880636f49010685da046f8cb0dc1c12ac220289e38e47f3f3a5ca9000000004847304402201bcae82a265158ea59176b0be5d27357ab5a884ad5ecc625bb10167445e3a17602201a481f9e0b9c047a42704856f8b87f2ed37c24199e12e26c440a891eadc8d55801feffffff02a8a3e60e000000001976a914514c4265de582bc90501c074d26b00225702d6a488ac00ca9a3b0000000017a9149e926338cfe3570700ad890501de6928ae777bfb87f4010000"
        
    }
    
    func getAddress() -> String {
        
        return "bc1qkfzq9uewaee8zqa4wv6dgg4d6jrvgyw2v4jg6p"
        
    }
    
    
}
