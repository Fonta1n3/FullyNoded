//
//  CreatePSBT.swift
//  BitSense
//
//  Created by Peter on 12/06/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class CreatePSBT {
    
    class func create(outputs: String, completion: @escaping ((psbt: String?, rawTx: String?, errorMessage: String?)) -> Void) {
        let feeTarget = UserDefaults.standard.object(forKey: "feeTarget") as? Int ?? 432
        let param = "[], ''{\(outputs)}'', 0, {\"includeWatching\": true, \"replaceable\": true, \"conf_target\": \(feeTarget)}, true"
        Reducer.makeCommand(command: .walletcreatefundedpsbt, param: param) { (response, errorMessage) in
            if let result = response as? NSDictionary {
                let psbt = result["psbt"] as! String
                Signer.sign(psbt: psbt) { (psbt, rawTx, errorMessage) in
                    completion((psbt, rawTx, errorMessage))
                }
            } else {
                completion((nil, nil, errorMessage ?? "unknown error"))
            }
        }
    }
    
}
