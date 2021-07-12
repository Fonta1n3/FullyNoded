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
        recipient = dictionary["destination"] as? String ?? "no recipient"
        memo = dictionary["description"] as? String ?? "no transaction memo"
        expiry = convertedDate(seconds: dictionary["expiry"] as! String)
        amount = dictionary["num_satoshis"] as? String ?? "\((Double(dictionary["num_msat"] as! String)! / 1000.0))"
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
