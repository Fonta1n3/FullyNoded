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
        var param = "[], ''{\(outputs)}'', 0, {\"includeWatching\": true, \"replaceable\": true, \"conf_target\": \(feeTarget)}, true"
        
        func create(params: String) {
            Reducer.makeCommand(command: .walletcreatefundedpsbt, param: params) { (response, errorMessage) in
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
        
        activeWallet { (wallet) in
            if wallet != nil {
                let descriptorParser = DescriptorParser()
                let descriptorStruct = descriptorParser.descriptor(wallet!.receiveDescriptor)
                if descriptorStruct.isMulti {
                    let index = Int(wallet!.index) + 1
                    CoreDataService.update(id: wallet!.id, keyToUpdate: "index", newValue: Int64(index), entity: .wallets) { (success) in
                        if success {
                            Reducer.makeCommand(command: .deriveaddresses, param: "\"\(wallet!.changeDescriptor)\", [\(index),\(index)]") { (response, errorMessage) in
                                if let result = response as? NSArray {
                                    if let changeAddress = result[0] as? String {
                                        param = "''[]'', ''{\(outputs)}'', 0, ''{\"includeWatching\": true, \"replaceable\": true, \"conf_target\": \(feeTarget), \"changeAddress\": \"\(changeAddress)\"}'', true"
                                        create(params: param)
                                    } else {
                                        completion((nil, nil, errorMessage ?? "error deriving multisig change address"))
                                    }
                                } else {
                                    completion((nil, nil, errorMessage ?? "error deriving multisig change address"))
                                }
                            }
                        } else {
                            completion((nil, nil, "error updating wallets index"))
                        }
                    }
                } else {
                    create(params: param)
                }
            } else {
                create(params: param)
            }
        }
        
    }
    
}
