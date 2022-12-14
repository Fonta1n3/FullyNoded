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
        Reducer.sharedInstance.makeCommand(command: .listwalletdir) { (response, errorMessage) in
            guard let walletDir = response as? [String:Any] else {
                completion((nil, errorMessage ?? "Unknown Error"))
                return
            }
            
            completion((WalletDir(walletDir), nil))
        }
    }
    
    static func listWallets(completion: @escaping ((wallets: [String]?, message: String?)) -> Void) {
        Reducer.sharedInstance.makeCommand(command: .listwallets) { (response, errorMessage) in
            guard let response = response as? [String] else {
                completion((nil, errorMessage ?? "Unknown error."))
                return
            }
            
            completion((response, nil))
        }
    }
    
    static func getWalletInfo(completion: @escaping ((walletInfo: WalletInfo?, message: String?)) -> Void) {
        Reducer.sharedInstance.makeCommand(command: .getwalletinfo) { (response, message) in
            guard let response = response as? [String:Any] else {
                completion((nil, message ?? "Unknown error."))
                return
            }
            
            completion((WalletInfo(response), nil))
        }
    }
    
    static func getDescriptorInfo(_ param: Get_Descriptor_Info, completion: @escaping ((descriptorInfo: DescriptorInfo?, message: String?)) -> Void) {
        Reducer.sharedInstance.makeCommand(command: .getdescriptorinfo(param: param)) { (response, message) in
            guard let response = response as? [String:Any] else {
                completion((nil, message ?? "Unknown error."))
                return
            }
            
            completion((DescriptorInfo(response), nil))
        }
    }
    
    static func importDescriptors(_ param: Import_Descriptors, completion: @escaping ((imported: Bool, message: String?)) -> Void) {
        Reducer.sharedInstance.makeCommand(command: .importdescriptors(param: param)) { (response, message) in
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
    
//    static func importMulti(_ param: String, completion: @escaping ((imported: Bool, message: String?)) -> Void) {
//        Reducer.sharedInstance.makeCommand(command: .importmulti, param: param) { (response, errorDescription) in
//            guard let result = response as? NSArray, result.count > 0,
//                  let dict = result[0] as? NSDictionary,
//                  let success = dict["success"] as? Bool,
//                  success else {
//                completion((false, errorDescription ?? "unknown error importing your keys"))
//                return
//            }
//            
//            completion((success, nil))
//        }
//    }
    
    static func rescan(completion: @escaping ((started: Bool, message: String?)) -> Void) {
        OnchainUtils.getBlockchainInfo { (blockchainInfo, message) in
            guard let blockchainInfo = blockchainInfo else {
                completion((false, message))
                return
            }
            
            guard blockchainInfo.pruned else {
                OnchainUtils.rescanNow(from: 0) { (started, message) in
                    completion((started, message))
                }
                
                return
            }
            
            OnchainUtils.rescanNow(from: blockchainInfo.pruneheight) { (started, message) in
                completion((started, message))
            }
        }
    }
    
    static func getBlockchainInfo(completion: @escaping ((blockchainInfo: BlockchainInfo?, message: String?)) -> Void) {
        Reducer.sharedInstance.makeCommand(command: .getblockchaininfo) { (response, errorMessage) in
            guard let dict = response as? [String:Any] else {
                completion((nil, errorMessage))
                return
            }
            
            completion((BlockchainInfo(dict), errorMessage))
        }
    }
    
    static func rescanNow(from: Int, completion: @escaping ((started: Bool, message: String?)) -> Void) {
        let param: Rescan_Blockchain = .init(["start_height": from])
        // current behavior of bitcoin core is to wait until the rescan completes before responding, which is terrible ux.
        // this command may fail, as a work around users need to refresh the home screen to see if it was successful.
        Reducer.sharedInstance.makeCommand(command: .rescanblockchain(param)) { (_, _) in
//            guard let errorMess = errorMess else {
//                completion((false, "unknown issue starting rescan."))
//                return
//            }
        }
        completion((true, nil))
        
    }
    
    static func createWallet(param: Create_Wallet_Param, completion: @escaping ((name: String?, message: String?)) -> Void) {
        Reducer.sharedInstance.makeCommand(command: .createwallet(param: param)) { (response, errorMessage) in
            guard let response = response as? [String:Any] else {
                completion((nil, errorMessage))
                return
            }
                        
            let warning = response["warning"] as? String
            let walletName = response["name"] as? String
            completion((walletName, warning))
        }
    }
    
    static func listUnspent(param: List_Unspent, completion: @escaping ((utxos: [Utxo]?, message: String?)) -> Void) {
        Reducer.sharedInstance.makeCommand(command: .listunspent(param)) { (response, errorMessage) in
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
    
    static func deriveAddresses(param: Derive_Addresses, completion: @escaping ((addresses: [String]?, message: String?)) -> Void) {        
        Reducer.sharedInstance.makeCommand(command: .deriveaddresses(param: param)) { (response, errorMessage) in
            guard let addresses = response as? [String] else {
                
                if let em = errorMessage, em.contains("Missing checksum") {
                    
                    let getdescinfo_p: Get_Descriptor_Info = .init(["descriptor":(param.param["descriptor"] as! String)])
                    
                    OnchainUtils.getDescriptorInfo(getdescinfo_p) { (descriptorInfo, message_) in
                        guard let descInfo = descriptorInfo else {
                            completion((nil, message_))
                            return
                        }
                        let newp:Derive_Addresses = .init(["descriptor": descInfo.descriptor, "range": param.param["range"] as! NSArray])
                        OnchainUtils.deriveAddresses(param: newp, completion: completion)
                    }
                    
                } else {
                    completion((nil, errorMessage))
                }
                return
            }
            
            completion((addresses, errorMessage))
        }
    }
    
    static func getAddressInfo(address: String, completion: @escaping ((addressInfo: AddressInfo?, message: String?)) -> Void) {
        let param:Get_Address_Info = .init(["address": address])
        Reducer.sharedInstance.makeCommand(command: .getaddressinfo(param: param)) { (response, errorMessage) in
            guard let response = response as? [String:Any] else {
                completion((nil, errorMessage))
                return
            }
            
            completion((AddressInfo(response), errorMessage))
        }
    }
    
    static func getBalance(completion: @escaping ((balance: Double?, message: String?)) -> Void) {
        let gb_param = [
            "dummy": "*",
            "minconf": 0,
            "include_watchonly": true,
            "avoid_reuse": false
        ] as [String:Any]
        
        Reducer.sharedInstance.makeCommand(command: .getbalance(param: .init(gb_param))) { (response, errorMessage) in
            guard let response = response as? Double else {
                guard let responseInt = response as? Int else {
                    completion((nil, errorMessage))
                    return
                }
                completion((Double(responseInt), errorMessage))
                return
            }
            completion((response, errorMessage))
        }
    }
    
    // MARK: TODO - add an address tool here to look up signers that can sign for a specific address.
    
    //        CoreDataService.retrieveEntity(entityName: .signers) { signers in
    //            guard let signers = signers else { return }
    //            for signer in signers {
    //                let s = SignerStruct(dictionary: signer)
    //                if let encWords = s.words {
    //                    guard let decryptedWords = Crypto.decrypt(encWords), let mk = Keys.masterKey(words: decryptedWords.utf8String!, coinType: "0", passphrase: ""), let xfp = Keys.fingerprint(masterKey: mk) else { return }
    //
    //
    //                    let possibleAddresses = [
    //
    //                    ]
    //                    JoinMarket.descriptors(mk, xfp) { descriptors in
    //                        guard let descriptors = descriptors else { return }
    //                        for descriptor in descriptors {
    //                            let p:Derive_Addresses = .init(["descriptor":descriptor, "range":[0,10]])
    //                            OnchainUtils.deriveAddresses(param: p) { (addresses, message) in
    //                                guard let addresses = addresses else { return }
    //                                for address in addresses {
    //                                    for possibleAddress in possibleAddresses {
    //                                        if address == possibleAddress {
    //                                            print("words: \(decryptedWords.utf8String!)")
    //                                            print("DING: \(address)")
    //                                        }
    //                                    }
    //                                }
    //                            }
    //                        }
    //                    }
    //                }
    //
    //            }
    //        }
     
}
