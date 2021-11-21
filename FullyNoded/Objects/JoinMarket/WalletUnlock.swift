//
//  WalletUnlock.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/21/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation
/*
 {
 token = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ3YWxsZXQiOiJGdWxseU5vZGVkLXlKeXE1aWJRd1Quam1kYXQiLCJleHAiOjE2Mzc1MDYxOTl9.CH0NwR6HqYXr6WLZgkVYoCQHOxLe2qUTvwUgJWDaTpo";
 walletname = "FullyNoded-yJyq5ibQwT.jmdat"
 }
 */

public struct WalletUnlock: CustomStringConvertible {
    let token: String
    let walletname: String
    
    init(_ dictionary: [String: Any]) {
        token = dictionary["token"] as! String
        walletname = dictionary["walletname"] as! String
    }
    
    public var description: String {
        return ""
    }
}
