//
//  OnchainUtils.swift
//  FullyNoded
//
//  Created by Peter Denton on 8/13/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

class OnchainUtils {
    
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
     
}
