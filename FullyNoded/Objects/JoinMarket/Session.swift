//
//  Session.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/23/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

struct JMSession: CustomStringConvertible {
    /*
     {
         "coinjoin_in_process" = 0;
         "maker_running" = 0;
         session = 1;
         "wallet_name" = "FullyNoded-yJyq5ibQwT.jmdat";
     }
     
     {
         "coinjoin_in_process" = 0;
         "maker_running" = 0;
         nickname = "<null>";
         "offer_list" = "<null>";
         schedule = "<null>";
         session = 0;
         "wallet_name" = None;
     }
     */
    let coinjoin_in_process:Bool
    let maker_running:Bool
    let session:Bool
    let wallet_name:String?
    
    init(_ dict: [String:Any]) {
        coinjoin_in_process = dict["coinjoin_in_process"] as! Bool
        maker_running = dict["maker_running"] as! Bool
        session = dict["session"] as! Bool
        wallet_name = dict["wallet_name"] as? String
    }
    
    public var description: String {
        return ""
    }
}
