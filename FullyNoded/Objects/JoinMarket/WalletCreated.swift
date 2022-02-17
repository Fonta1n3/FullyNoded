//
//  WalletCreated.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/21/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

/*
 json: {
     seedphrase = "supply argue stove economy wish city ice guess theme orbit wear mimic";
     token = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ3YWxsZXQiOiJ0ZXN0LmptZGF0IiwiZXhwIjoxNjM3NDg4OTQ0fQ.EjYRKEDsiet5Kd3a4kDY95YZxAHgS2dzJSwWWIrGNfU";
     walletname = "test.jmdat";
 }
 */

public struct JMWalletCreated: CustomStringConvertible {
    let seedphrase: String
    let token: String
    let walletname: String
    
    init(_ dictionary: [String: Any]) {
        seedphrase = dictionary["seedphrase"] as! String
        token = dictionary["token"] as! String
        walletname = dictionary["walletname"] as? String ?? ""
    }
    
    public var description: String {
        return ""
    }
}
