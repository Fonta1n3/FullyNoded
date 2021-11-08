//
//  CreatePSBT.swift
//  BitSense
//
//  Created by Peter on 12/06/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class CreatePSBT {
    
    class func create(inputs: String, outputs: String, completion: @escaping ((psbt: String?, rawTx: String?, errorMessage: String?)) -> Void) {
        var param = ""
        
        if let feeRate = UserDefaults.standard.object(forKey: "feeRate") as? Int {
            param = "[], ''{\(outputs)}'', 0, {\"includeWatching\": true, \"replaceable\": true, \"fee_rate\": \(feeRate)}, true"
            
            if inputs != "" {
                param = "\(inputs), ''{\(outputs)}'', 0, {\"includeWatching\": true, \"replaceable\": true, \"fee_rate\": \(feeRate)}, true"
            }
            
        } else if let feeTarget = UserDefaults.standard.object(forKey: "feeTarget") as? Int {
            param = "[], ''{\(outputs)}'', 0, {\"includeWatching\": true, \"replaceable\": true, \"conf_target\": \(feeTarget)}, true"
            
            if inputs != "" {
                param = "\(inputs), ''{\(outputs)}'', 0, {\"includeWatching\": true, \"replaceable\": true, \"conf_target\": \(feeTarget)}, true"
            }
        }
        
        func create(params: String) {
            Reducer.makeCommand(command: .walletcreatefundedpsbt, param: params) { (response, errorMessage) in
                guard let result = response as? NSDictionary, let psbt = result["psbt"] as? String else {
                    var desc = errorMessage ?? "unknown error"
                    if desc.contains("Unexpected key fee_rate") {
                        desc = "In order to set the fee rate manually you must update to Bitcoin Core 0.21."
                    }
                    completion((nil, nil, desc))
                    return
                }
                
                Signer.sign(psbt: psbt, passphrase: nil) { (psbt, rawTx, errorMessage) in
                    completion((psbt, rawTx, errorMessage))
                }
            }
        }
        
        activeWallet { wallet in
            guard let wallet = wallet else {
                // using a bitcoin core wallet
                Reducer.makeCommand(command: .getrawchangeaddress, param: "") { (response, errorMessage) in
                    guard let changeAddress = response else {
                        completion((nil, nil, "error getting a change address: \(errorMessage ?? "unknown")"))
                        return
                    }
                        
                    if let feeRate = UserDefaults.standard.object(forKey: "feeRate") as? Int {
                        
                        param = "''[]'', ''{\(outputs)}'', 0, ''{\"includeWatching\": true, \"replaceable\": true, \"fee_rate\": \(feeRate), \"changeAddress\": \"\(changeAddress)\"}'', true"
                        
                        if inputs != "" {
                            param = "\(inputs), ''{\(outputs)}'', 0, ''{\"includeWatching\": true, \"replaceable\": true, \"fee_rate\": \(feeRate), \"changeAddress\": \"\(changeAddress)\"}'', true"
                        }
                    } else if let feeTarget = UserDefaults.standard.object(forKey: "feeTarget") as? Int {
                        
                        param = "''[]'', ''{\(outputs)}'', 0, ''{\"includeWatching\": true, \"replaceable\": true, \"conf_target\": \(feeTarget), \"changeAddress\": \"\(changeAddress)\"}'', true"
                        
                        if inputs != "" {
                            param = "\(inputs), ''{\(outputs)}'', 0, ''{\"includeWatching\": true, \"replaceable\": true, \"conf_target\": \(feeTarget), \"changeAddress\": \"\(changeAddress)\"}'', true"
                        }
                    }
                    
                    create(params: param)
                }
                
                return
            }
            
            let descriptorStruct = Descriptor(wallet.receiveDescriptor)
            
            guard descriptorStruct.isMulti && wallet.type != WalletType.descriptor.stringValue else {
                create(params: param)
                return
            }
            
            let index = Int(wallet.index) + 1
            
            CoreDataService.update(id: wallet.id, keyToUpdate: "index", newValue: Int64(index), entity: .wallets) { success in
                guard success else {
                    completion((nil, nil, "error updating wallets index"))
                    return
                }
                
                Reducer.makeCommand(command: .deriveaddresses, param: "\"\(wallet.changeDescriptor)\", [\(index),\(index)]") { (response, errorMessage) in
                    guard let result = response as? NSArray, let changeAddress = result[0] as? String else {
                        completion((nil, nil, errorMessage ?? "error deriving multisig change address"))
                        return
                    }
                        
                    if let feeRate = UserDefaults.standard.object(forKey: "feeRate") as? Int {
                        
                        param = "''[]'', ''{\(outputs)}'', 0, ''{\"includeWatching\": true, \"replaceable\": true, \"fee_rate\": \(feeRate), \"changeAddress\": \"\(changeAddress)\"}'', true"
                        
                        if inputs != "" {
                            param = "\(inputs), ''{\(outputs)}'', 0, ''{\"includeWatching\": true, \"replaceable\": true, \"fee_rate\": \(feeRate), \"changeAddress\": \"\(changeAddress)\"}'', true"
                        }
                    } else if let feeTarget = UserDefaults.standard.object(forKey: "feeTarget") as? Int {
                        
                        param = "''[]'', ''{\(outputs)}'', 0, ''{\"includeWatching\": true, \"replaceable\": true, \"conf_target\": \(feeTarget), \"changeAddress\": \"\(changeAddress)\"}'', true"
                        
                        if inputs != "" {
                            param = "\(inputs), ''{\(outputs)}'', 0, ''{\"includeWatching\": true, \"replaceable\": true, \"conf_target\": \(feeTarget), \"changeAddress\": \"\(changeAddress)\"}'', true"
                        }
                    }
                    
                    create(params: param)
                }
            }
        }
    }
}
