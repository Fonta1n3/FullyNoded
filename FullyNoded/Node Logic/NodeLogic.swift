//
//  NodeLogic.swift
//  BitSense
//
//  Created by Peter on 26/08/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class NodeLogic {
    
    static let sharedInstance = NodeLogic()
    
    private init() {}
    
            
    func getPeerInfo(completion: @escaping ((response: GetPeerInfoResponse?, errorMessage: String?)) -> Void) {
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getpeerinfo) { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            if let peerInfo = response as? NSArray {
                parsePeerInfo(peerInfo: peerInfo, completion: completion)
            } else {
                 completion((nil, errorMessage ?? ""))
            }
        }
    }
    
    func getNetworkInfo(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getnetworkinfo) { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            if let networkInfo = response as? [String:Any] {
                parseNetworkInfo(networkInfo: networkInfo, completion: completion)
            } else {
                completion((nil, errorMessage ?? ""))
            }
        }
    }
    
    func getMiningInfo(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getmininginfo) { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            if let miningInfo = response as? [String:Any] {
                parseMiningInfo(miningInfo: miningInfo, completion: completion)
            } else {
                completion((nil, errorMessage ?? ""))
            }
        }
    }
    
    func getUptime(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .uptime) { (response, errorMessage) in
            if let uptime = response as? Double {
                var toReturn = [String:Any]()
                toReturn["uptime"] = Int(uptime)
                completion((toReturn, nil))
            } else {
                completion((nil, errorMessage ?? ""))
            }
        }
    }
    
    func getMempoolInfo(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getmempoolinfo) { (response, errorMessage) in
            if let dict = response as? [String:Any] {
                var mempoolInfo = [String:Any]()
                mempoolInfo["mempoolCount"] = dict["size"] as? Int ?? 0
                mempoolInfo["rawData"] = dict
                completion((mempoolInfo, nil))
            } else {
                completion((nil, errorMessage ?? ""))
            }
        }
    }
    
    func estimateSmartFee(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        let feeRate = UserDefaults.standard.integer(forKey: "feeTarget")
        let param:Estimate_Smart_Fee_Param = .init(["conf_target":feeRate])
        var dictToReturn: [String: Any] = [:]
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .estimatesmartfee(param: param)) { (response, errorMessage) in
            if let result = response as? [String:Any] {
                if let feeRate = result["feerate"] as? Double {
                    let btcperbyte = feeRate / 1000
                    let satsperbyte = (btcperbyte * 100000000).avoidNotation
                    dictToReturn["feeRate"] = "\(satsperbyte) sats/byte"
                    completion((dictToReturn, nil))
                } else {
                    if let errors = result["errors"] as? NSArray {
                        dictToReturn["feeRate"] = "\(errors[0] as! String)"
                        completion((dictToReturn, nil))
                    }
                }
            } else {
                completion((nil, errorMessage ?? ""))
            }
        }
    }
    
    // MARK: Parsers
    
    private func parseMiningInfo(miningInfo: [String:Any], completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        var miningInfoToReturn = [String:Any]()
        let hashesPerSecond = miningInfo["networkhashps"] as? Double ?? 0.0
        let exahashesPerSecond = hashesPerSecond / 1000000000000000000
        miningInfoToReturn["networkhashps"] = Int(exahashesPerSecond).withCommas
        miningInfoToReturn["rawData"] = miningInfo
        completion((miningInfoToReturn, nil))
    }
    
    private func parsePeerInfo(peerInfo: NSArray, completion: @escaping ((response: GetPeerInfoResponse?, errorMessage: String?)) -> Void) {
       guard let getPeerInfoResponse = try? GetPeerInfoResponse(from: peerInfo) else {
           completion((nil, "Error parsing peer info, please let us know about this."))
            return
        }
    
        completion((getPeerInfoResponse, nil))
    }
    
    private func parseNetworkInfo(networkInfo: [String:Any], completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        var networkInfoToReturn = [String:Any]()
        networkInfoToReturn["subversion"] = networkInfo["subversion"] as? String ?? ""
        // Only store a version we actually read: other RPCs choose parameters by it.
        if let versionInt = RPCValue.int(networkInfo["version"]) {
            UserDefaults.standard.set(versionInt, forKey: "version")
            PSBTVersion.nodeRejectedParam = false
        }
        
        let networks = networkInfo["networks"] as? [[String: Any]] ?? []
        
        for network in networks where network["name"] as? String == "onion" {
            networkInfoToReturn["reachable"] = RPCValue.bool(network["reachable"]) ?? false
        }
        
        networkInfoToReturn["rawData"] = networkInfo
        
        completion((networkInfoToReturn, nil))
    }
}
