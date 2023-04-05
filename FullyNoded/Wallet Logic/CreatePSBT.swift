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
        
        func wallet_create(param: Wallet_Create_Funded_Psbt) {
            Reducer.sharedInstance.makeCommand(command: .walletcreatefundedpsbt(param: param)) { (response, errorMessage) in
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
                Reducer.sharedInstance.makeCommand(command: .getrawchangeaddress) { (response, errorMessage) in
                    guard let changeAddress = response else {
                        completion((nil, nil, "error getting a change address: \(errorMessage ?? "unknown")"))
                        return
                    }
                    options["changeAddress"] = changeAddress
                    paramDict["options"] = options
                    let param = Wallet_Create_Funded_Psbt(paramDict)
                    wallet_create(param: param)
                }
                return
            }

            let index = Int(wallet.index) + 1

            CoreDataService.update(id: wallet.id, keyToUpdate: "index", newValue: Int64(index), entity: .wallets) { success in
                guard success else {
                    completion((nil, nil, "error updating wallets index"))
                    return
                }
                let param: Derive_Addresses = .init(["descriptor":wallet.changeDescriptor, "range": [index,index]])
                OnchainUtils.deriveAddresses(param: param) { (addresses, message) in
                    guard let addresses = addresses as? NSArray, let changeAddress = addresses[0] as? String else {
                        completion((nil, nil, message ?? "error deriving change address"))
                        return
                    }
                    options["changeAddress"] = changeAddress
                    paramDict["options"] = options
                    let param = Wallet_Create_Funded_Psbt(paramDict)
                    wallet_create(param: param)
                }
            }
        }
    }
}
