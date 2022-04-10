//
//  InvoiceStruct.swift
//  FullyNoded
//
//  Created by Peter Denton on 7/11/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

public struct InvoiceStruct: CustomStringConvertible, Codable {
    
    let memo: String
    let recipient: String
    let expiry: String
    let amount: String
    let userSpecifiedAmount:String?
    
    init(_ dictionary: [String: Any]) {
        recipient = dictionary["destination"] as? String ?? dictionary["payee"] as? String ?? "unknown"
        
        memo = dictionary["description"] as? String ?? "no transaction memo"
        
        if let expiryString = dictionary["expiry"] as? String {
            expiry = convertedDate(seconds: expiryString)
        } else {
            let expiryInt = dictionary["expiry"] as! Int
            expiry = convertedDate(seconds: "\(expiryInt)")
        }
        
        if let num_satoshis = dictionary["num_satoshis"] as? String {
            amount = num_satoshis
        } else if let num_msat = dictionary["num_msat"] as? String {
            amount = "\(Double(num_msat)! / 1000.0)"
        } else if let msatoshi = dictionary["msatoshi"] as? Double {
            amount = "\(msatoshi / 1000.0)"
        } else {
            amount = "0"
        }
        
        userSpecifiedAmount = dictionary["userSpecifiedAmount"] as? String
    }
    
    public var description: String {
        return ""
    }
    
}

private func convertedDate(seconds: String) -> String {
    let date = Date(timeIntervalSinceNow: Double(seconds)!)
    return date.displayDate
    
}
