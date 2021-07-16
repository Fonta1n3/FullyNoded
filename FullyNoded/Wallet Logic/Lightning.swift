//
//  Lightning.swift
//  FullyNoded
//
//  Created by Peter on 05/08/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

class Lightning {
    
    class func connect(amount: Int, id: String, ip: String?, port: String?, completion: @escaping ((result: NSDictionary?, errorMessage: String?)) -> Void) {
        var param = "\(id)"
        
        if let ip = ip {
            param += "@\(ip)"
        }
        
        if let port = port {
            param += ":\(port)"
        }
        
        let commandId = UUID()
        LightningRPC.command(id: commandId, method: .connect, param: "\(param)") { (uuid, response, errorDesc) in
            if commandId == uuid {
                if let dict = response as? NSDictionary {
                    parseConnection(amount: amount, dict: dict, completion: completion)
                } else {
                    completion((nil, errorDesc ?? "unknown error connecting to that node"))
                }
            }
        }
    }
    
    class func parseConnection(amount: Int, dict: NSDictionary, completion: @escaping ((result: NSDictionary?, errorMessage: String?)) -> Void) {
        if let id = dict["id"] as? String {
            Lightning.getClosingAddress(channelId: id, amount: amount, completion: completion)
        } else {
            completion((nil, "error parsing the connection result"))
        }
    }
    
    class func getClosingAddress(channelId: String, amount: Int, completion: @escaping ((result: NSDictionary?, errorMessage: String?)) -> Void) {
        activeWallet { wallet in
            guard let wallet = wallet else {
                completion((nil, "No active wallet, in order to create a channel you need to be using an active FN onchain wallet. This can be single sig, multisig, hot or cold. Funds will always be returned to this wallet when this channel closes. The channel will be funded directly from your active FN wallet."))
                return
            }
            
            if wallet.type != "Native-Descriptor" {
                let index = Int(wallet.index) + 1
                let param = "\"\(wallet.receiveDescriptor)\", [\(index),\(index)]"
                
                Reducer.makeCommand(command: .deriveaddresses, param: param) { (response, errorMessage) in
                    guard let addresses = response as? NSArray, let address = addresses[0] as? String else {
                        completion((nil, "Error getting closing address: \(errorMessage ?? "unknown")"))
                        return
                    }
                    
                    Lightning.fundchannelstart(channelId: channelId, amount: amount, address: address, completion: completion)
                }
            } else {
                Reducer.makeCommand(command: .getnewaddress, param: "") { (response, errorMessage) in
                    guard let address = response as? String else {
                        completion((nil, "Error getting closing address: \(errorMessage ?? "unknown")"))
                        return
                    }
                    
                    Lightning.fundchannelstart(channelId: channelId, amount: amount, address: address, completion: completion)
                }
            }
        }
    }
    
    class func fundchannelstart(channelId: String, amount: Int, address: String, completion: @escaping ((result: NSDictionary?, errorMessage: String?)) -> Void) {
        let param = "\"\(channelId)\", \(amount), \"normal\", false, \"\(address)\""
        let commandId = UUID()
        
        LightningRPC.command(id: commandId, method: .fundchannel_start, param: param) { (uuid, response, errorDesc) in
            if commandId == uuid {
                if let fundedChannelDict = response as? NSDictionary {
                    Lightning.parseFundChannelStart(channelId: channelId, amount: amount, dict: fundedChannelDict, completion: completion)
                } else {
                    completion((nil, errorDesc ?? "unknown error funding that channel"))
                }
            }
        }
    }
    
    class func parseFundChannelStart(channelId: String, amount: Int, dict: NSDictionary, completion: @escaping ((result: NSDictionary?, errorMessage: String?)) -> Void) {
        if let address = dict["funding_address"] as? String, let scriptPubKey = dict["scriptpubkey"] as? String {
            createFundingPsbt(channelId, scriptPubKey, address, amount, completion: completion)
        } else {
            completion((nil, "error parsing channel funding start"))
        }
    }
    
    class func createFundingPsbt(_ channelId: String,
                                 _ scriptPubKey: String,
                                 _ address: String,
                                 _ amount: Int, completion: @escaping ((result: NSDictionary?, errorMessage: String?)) -> Void) {
        
        let btcAmount = "\(rounded(number: Double(amount) / 100000000.0).avoidNotation)"
        
        CreatePSBT.create(inputs: "", outputs: "\"\(address)\":\(btcAmount)") { (psbt, rawTx, errorMessage) in
            guard errorMessage == nil else {
                completion((nil, "Error creating funding psbt: \(errorMessage ?? "unknown error")"))
                return
            }
            
            guard let psbt = psbt else {
                
                guard let rawTx = rawTx else {
                    return
                }
                
                decodeFundingTx(rawTx, channelId, scriptPubKey, address, amount, completion: completion)
                
                return
            }
            
            UserDefaults.standard.setValue(scriptPubKey, forKey: "scriptPubKey")
            UserDefaults.standard.setValue(address, forKey: "address")
            UserDefaults.standard.setValue(amount, forKey: "amount")
            UserDefaults.standard.setValue(channelId, forKey: "channelId")
            
            completion((["psbt":psbt], nil))
        }
    }
    
    class func decodeFundingTx(_ rawTx: String,
                               _ channelId: String,
                               _ scriptPubKey: String,
                               _ address: String,
                               _ amount: Int, completion: @escaping ((result: NSDictionary?, errorMessage: String?)) -> Void) {
        
        Reducer.makeCommand(command: .decoderawtransaction, param: "\"\(rawTx)\"") { (response, errorMessage) in
            guard let response = response as? [String:Any],
                  let txid = response["txid"] as? String,
                  let outputs = response["vout"] as? NSArray,
                  outputs.count > 0 else {
                    completion((nil, "error decoding funding tx: \(errorMessage ?? "unknown error")"))
                    return
                  }
            
            for output in outputs {
                if let outputDict = output as? NSDictionary {
                    if let index = outputDict["n"] as? Int {
                        if let spk = outputDict["scriptPubKey"] as? [String:Any] {
                            if let hex = spk["hex"] as? String {
                                if hex == scriptPubKey {
                                    Lightning.fundchannelcomplete(channelId: channelId, txid: txid, vout: index, rawTx: rawTx, completion: completion)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    class func fundchannelcomplete(channelId: String, txid: String, vout: Int, rawTx: String, completion: @escaping ((result: NSDictionary?, errorMessage: String?)) -> Void) {
        let param = "\"\(channelId)\", \"\(txid)\", \(vout)"
        let commandId = UUID()
        
        LightningRPC.command(id: commandId, method: .fundchannel_complete, param: param) { (uuid, response, errorDesc) in
            guard commandId == uuid, let dict = response as? NSDictionary, let commitments_secured = dict["commitments_secured"] as? Bool, commitments_secured else {
                completion((nil, "Transaction not sent! Funding completion failed." + (errorDesc ?? "Unknown error completing the channel funding.")))
                return
            }
            
            Reducer.makeCommand(command: .sendrawtransaction, param: "\"\(rawTx)\"") { (response, errorMessage) in
                guard let _ = response as? String else {
                    completion((["rawTx":rawTx], "There was an issue broadcasting your funding transaction. Error: \(errorMessage ?? "unknown error")"))
                    return
                }
                
                UserDefaults.standard.removeObject(forKey: "scriptPubKey")
                UserDefaults.standard.removeObject(forKey: "address")
                UserDefaults.standard.removeObject(forKey: "amount")
                UserDefaults.standard.removeObject(forKey: "channelId")
                
                let memo = "⚡️ channel \(channelId) funded with Fully Noded psbt."
                saveTx(memo: memo, txid: txid, completion: completion)                
            }
        }
    }
    
    class private func saveTx(memo: String, txid: String, completion: @escaping ((result: NSDictionary?, errorMessage: String?)) -> Void) {
        FiatConverter.sharedInstance.getFxRate { fxRate in
            var dict:[String:Any] = ["txid":txid, "id":UUID(), "memo":memo, "date":Date(), "label":"Fully Noded ⚡️ psbt channel funding."]
            
            guard let originRate = fxRate else {
                CoreDataService.saveEntity(dict: dict, entityName: .transactions) { _ in }
                completion((["success": true], nil))
                return
            }
            
            dict["originFxRate"] = originRate
                        
            CoreDataService.saveEntity(dict: dict, entityName: .transactions) { _ in }
            
            completion((["success": true], nil))
        }
    }
}
