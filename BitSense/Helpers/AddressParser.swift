//
//  AddressParser.swift
//  BitSense
//
//  Created by Peter on 01/05/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class AddressParser {
    
    var url = ""
    
    func parseAddress(url: String) -> (address: String, amount: Double, errorBool: Bool, errorDescription: String) {
        
        var addressToReturn = ""
        var amountToReturn = Double()
        var errorBool = Bool()
        var errorDescription = ""
        
        func getaddress(processedKey: String) {
            
            func verifyAddress(key: String) -> Bool {
                
                var boolToReturn = Bool()
                
                var prefix = key.lowercased()
                
                prefix = prefix.replacingOccurrences(of: "bitcoin:",
                                                     with: "")
                
                switch prefix {
                    
                case _ where prefix.hasPrefix("1"),
                     _ where prefix.hasPrefix("3"),
                     _ where prefix.hasPrefix("tb1"),
                     _ where prefix.hasPrefix("bc1"),
                     _ where prefix.hasPrefix("2"),
                     _ where prefix.hasPrefix("bcrt"),
                     _ where prefix.hasPrefix("m"),
                     _ where prefix.hasPrefix("n"):
                    
                    boolToReturn = true
                    
                default:
                    
                    boolToReturn = false
                    
                }
                
                return boolToReturn
                
            }
            
            if verifyAddress(key: processedKey) {
                
                errorBool = false
                addressToReturn = processedKey
                
            } else {
                
                errorBool = true
                errorDescription = "Thats not a valid Bitcoin address"
                
            }
            
        }
        
        var address = url
        
        //bitcoin:175tWpb8K1S7NmH4Zx6rewF9WQrcZv245W?amount=20.3&label=Luke-Jr
        
        if address.contains("bitcoin:") || address.contains("?") || address.contains("=") {
            
            if address.hasPrefix(" ") {
                
                address = address.replacingOccurrences(of: " ",
                                                       with: "")
                
            }
            
            if address.hasPrefix("bitcoin:") {
                
                address = address.replacingOccurrences(of: "bitcoin:", with: "")
                
            }
            
            if address.contains("?") {
                
                let formatArray = address.split(separator: "?")
                
                let address = formatArray[0].replacingOccurrences(of: "bitcoin:",
                                                                  with: "")
                
                getaddress(processedKey: address)
                
                if formatArray[1].contains("amount=") && formatArray[1].contains("&") {
                    
                    let array = formatArray[1].split(separator: "&")
                    
                    let amount = array[0].replacingOccurrences(of: "amount=",
                                                               with: "")
                    
                    amountToReturn = Double(amount)!
                    
                } else if formatArray[1].contains("amount=") {
                    
                    let amount = formatArray[1].replacingOccurrences(of: "amount=",
                                                                     with: "")
                    
                    amountToReturn = Double(amount)!
                    
                }
                
            } else {
                
                getaddress(processedKey: address)
                
            }
            
        } else {
            
            getaddress(processedKey: address)
            
        }
        
        return (address: addressToReturn,
                amount: amountToReturn,
                errorBool: errorBool,
                errorDescription: errorDescription)
        
    }
    
}
