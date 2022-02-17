//
//  OnchainUtils.swift
//  FullyNoded
//
//  Created by Peter Denton on 8/13/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

class OnchainUtils {
    static func listWalletDir(completion: @escaping ((wallets: WalletDir?, message: String?)) -> Void) {
        Reducer.makeCommand(command: .listwalletdir, param: "") { (response, errorMessage) in
            guard let walletDir = response as? [String:Any] else {
                completion((nil, errorMessage ?? "Unknown Error"))
                return
            }
            
            completion((WalletDir(walletDir), nil))
        }
    }
    
    static func listWallets(completion: @escaping ((wallets: [String]?, message: String?)) -> Void) {
        Reducer.makeCommand(command: .listwallets, param: "") { (response, errorMessage) in
            guard let response = response as? [String] else {
                completion((nil, errorMessage ?? "Unknown error."))
                return
            }
            
            completion((response, nil))
        }
    }
    
    static func getWalletInfo(completion: @escaping ((walletInfo: WalletInfo?, message: String?)) -> Void) {
        Reducer.makeCommand(command: .getwalletinfo, param: "") { (response, message) in
            guard let response = response as? [String:Any] else {
                completion((nil, message ?? "Unknown error."))
                return
            }
            
            completion((WalletInfo(response), nil))
        }
    }
    
    static func getDescriptorInfo(_ desc: String, completion: @escaping ((descriptorInfo: DescriptorInfo?, message: String?)) -> Void) {
        Reducer.makeCommand(command: .getdescriptorinfo, param: "\"\(desc)\"") { (response, message) in
            guard let response = response as? [String:Any] else {
                completion((nil, message ?? "Unknown error."))
                return
            }
            
            completion((DescriptorInfo(response), nil))
        }
    }
    
    static func importDescriptors(_ param: String, completion: @escaping ((imported: Bool, message: String?)) -> Void) {
        Reducer.makeCommand(command: .importdescriptors, param: param) { (response, message) in
            guard let responseArray = response as? [[String:Any]] else {
                completion((false, "Error importing descriptors: \(message ?? "unknown error")"))
                return
            }
            
            var warnings:String?
            
            for (i, response) in responseArray.enumerated() {
                var errorMessage = ""
                
                guard let success = response["success"] as? Bool, success else {
                    if let error = response["error"] as? [String:Any], let messageCheck = error["message"] as? String {
                        errorMessage = "Error importing descriptors: \(messageCheck)"
                    }
                    
                    completion((false, errorMessage))
                    return
                }
                
                if let warningsCheck = response["warnings"] as? [String] {
                    warnings = warningsCheck.description
                }
                                
                if i + 1 == responseArray.count {
                    completion((true, warnings))
                }
            }
        }
    }
    
    static func importMulti(_ param: String, completion: @escaping ((imported: Bool, message: String?)) -> Void) {
        Reducer.makeCommand(command: .importmulti, param: param) { (response, errorDescription) in
            guard let result = response as? NSArray, result.count > 0,
                  let dict = result[0] as? NSDictionary,
                  let success = dict["success"] as? Bool,
                  success else {
                completion((false, errorDescription ?? "unknown error importing your keys"))
                return
            }
            
            completion((success, nil))
        }
    }
    
    static func rescan(completion: @escaping ((started: Bool, message: String?)) -> Void) {
        OnchainUtils.getBlockchainInfo { (blockchainInfo, message) in
            guard let blockchainInfo = blockchainInfo else {
                completion((false, message))
                return
            }
            
            guard blockchainInfo.pruned else {
                OnchainUtils.rescanNow(from: "0") { (started, message) in
                    completion((started, message))
                }
                
                return
            }
            
            OnchainUtils.rescanNow(from: "\(blockchainInfo.pruneheight)") { (started, message) in
                completion((started, message))
            }
        }
    }
    
    static func getBlockchainInfo(completion: @escaping ((blockchainInfo: BlockchainInfo?, message: String?)) -> Void) {
        Reducer.makeCommand(command: .getblockchaininfo, param: "") { (response, errorMessage) in
            guard let dict = response as? [String:Any] else {
                completion((nil, errorMessage))
                return
            }
            
            completion((BlockchainInfo(dict), errorMessage))
        }
    }
    
    static func rescanNow(from: String, completion: @escaping ((started: Bool, message: String?)) -> Void) {
        Reducer.makeCommand(command: .rescanblockchain, param: "\(from)") { (_, _) in }
        completion((true, nil))
    }
    
    static func createWallet(param: String, completion: @escaping ((name: String?, message: String?)) -> Void) {
        Reducer.makeCommand(command: .createwallet, param: param) { (response, errorMessage) in
            guard let response = response as? [String:Any] else {
                completion((nil, errorMessage))
                return
            }
                        
            let warning = response["warning"] as? String
            let walletName = response["name"] as? String
            completion((walletName, warning))
        }
    }
    
    static func listUnspent(param: String, completion: @escaping ((utxos: [Utxo]?, message: String?)) -> Void) {
        Reducer.makeCommand(command: .listunspent, param: param) { (response, errorMessage) in
            guard let response = response as? [[String:Any]] else {
                completion((nil, errorMessage))
                return
            }
            
            guard response.count > 0 else {
                completion(([], nil))
                return
            }
            
            var utxosToReturn = [Utxo]()
            
            for (i, dict) in response.enumerated() {
                utxosToReturn.append(Utxo(dict))
                
                if i + 1 == response.count {
                    completion((utxosToReturn, nil))
                }
            }
        }
    }
    
    static func deriveAddresses(param: String, completion: @escaping ((addresses: [String]?, message: String?)) -> Void) {
        Reducer.makeCommand(command: .deriveaddresses, param: param) { (response, errorMessage) in
            guard let addresses = response as? [String] else {
                completion((nil, errorMessage))
                return
            }
            
            completion((addresses, errorMessage))
        }
    }
    
    static func getAddressInfo(address: String, completion: @escaping ((addressInfo: AddressInfo?, message: String?)) -> Void) {
        let param = "\"\(address)\""
        Reducer.makeCommand(command: .getaddressinfo, param: param) { (response, errorMessage) in
            guard let response = response as? [String:Any] else {
                completion((nil, errorMessage))
                return
            }
            
            completion((AddressInfo(response), errorMessage))
        }
    }
     
}
