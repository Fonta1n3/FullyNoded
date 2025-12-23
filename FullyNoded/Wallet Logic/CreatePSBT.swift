//
//  CreatePSBT.swift
//  BitSense
//
//  Created by Peter on 12/06/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class CreatePSBT {
    
    class func create(inputs: [[String:Any]], outputs: [[String:Any]], completion: @escaping ((psbt: String?, rawTx: String?, errorMessage: String?)) -> Void) {
        
        var paramDict:[String:Any] = [:]
        paramDict["outputs"] = outputs
        paramDict["inputs"] = inputs
        paramDict["bip32derivs"] = true
        
        var options:[String:Any] = [:]
        options["includeWatching"] = true
        options["replaceable"] = true
        
        if let feeRate = UserDefaults.standard.object(forKey: "feeRate") as? Int {
            options["fee_rate"] = feeRate
        } else if let feeTarget = UserDefaults.standard.object(forKey: "feeTarget") as? Int {
            options["conf_target"] = feeTarget
        }
        
        let param = Wallet_Create_Funded_Psbt(paramDict)
        
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .walletcreatefundedpsbt(param: param)) { (response, errorMessage) in
            guard let result = response as? NSDictionary, let psbt = result["psbt"] as? String else {
                var desc = errorMessage ?? "unknown error"
                if desc.contains("Unexpected key fee_rate") {
                    desc = "In order to set the fee rate manually you must update to Bitcoin Core 0.21."
                }
                completion((nil, nil, desc))
                return
            }
            
            completion((psbt, nil, nil))
        }
    }
}
