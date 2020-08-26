//
//  Lightning.swift
//  FullyNoded
//
//  Created by Peter on 05/08/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

class Lightning {
    
    class func connect(amount: Int, id: String, ip: String, port: String?, completion: @escaping ((result: NSDictionary?, errorMessage: String?)) -> Void) {
        let param = "\(id)@\(ip):\(port ?? "9735")"
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
            Lightning.fundchannelstart(channelId: id, amount: amount, completion: completion)
        } else {
            completion((nil, "error parsing the connection result"))
        }
    }
    
    class func fundchannelstart(channelId: String, amount: Int, completion: @escaping ((result: NSDictionary?, errorMessage: String?)) -> Void) {
        let param = "\"\(channelId)\", \(amount)"
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
            Lightning.txprepare(channelId: channelId, scriptPubKey: scriptPubKey, address: address, amount: amount, completion: completion)
        } else {
            completion((nil, "error parsing channel funding start"))
        }
    }
    
    class func txprepare(channelId: String, scriptPubKey: String, address: String, amount: Int, completion: @escaping ((result: NSDictionary?, errorMessage: String?)) -> Void) {
        let commandId = UUID()
        let param = "\"\(address)\", \(amount)"
        LightningRPC.command(id: commandId, method: .txprepare, param: param) { (uuid, response, errorDesc) in
            if commandId == uuid {
                if let dict = response as? NSDictionary {
                    Lightning.parseTxPrepareResult(channelId: channelId, scriptPubKey: scriptPubKey, dict: dict, completion: completion)
                } else {
                    completion((nil, errorDesc ?? "unknown error preparing channel funding transaction"))
                }
            }
        }
    }
    
    class func parseTxPrepareResult(channelId: String, scriptPubKey: String, dict: NSDictionary, completion: @escaping ((result: NSDictionary?, errorMessage: String?)) -> Void) {
        if let txid = dict["txid"] as? String {
            Lightning.txsend(channelId: channelId, scriptPubKey: scriptPubKey, txid: txid, completion: completion)
        } else {
            completion((nil, "error parsing tx prepare result"))
        }
    }
    
    class func txsend(channelId: String, scriptPubKey: String, txid: String, completion: @escaping ((result: NSDictionary?, errorMessage: String?)) -> Void) {
        let param = "\"\(txid)\""
        let commandId = UUID()
        LightningRPC.command(id: commandId, method: .txsend, param: param) { (uuid, response, errorDesc) in
            if commandId == uuid {
                if let dict = response as? NSDictionary {
                    Lightning.parseTxSendResult(channelId: channelId, scriptPubKey: scriptPubKey, dict: dict, completion: completion)
                } else {
                    completion((nil, errorDesc ?? "unknown error sending transaction"))
                }
            }
        }
    }
    
    class func parseTxSendResult(channelId: String, scriptPubKey: String, dict: NSDictionary, completion: @escaping ((result: NSDictionary?, errorMessage: String?)) -> Void) {
        if let txid = dict["txid"] as? String {
            Lightning.listtransactions(channelId: channelId, scriptPubKey: scriptPubKey, txid: txid, completion: completion)
        } else {
            completion((nil, "unknown error parsing tx send result"))
        }
    }
    
    class func listtransactions(channelId: String, scriptPubKey: String, txid: String, completion: @escaping ((result: NSDictionary?, errorMessage: String?)) -> Void) {
        let commandId = UUID()
        LightningRPC.command(id: commandId, method: .listtransactions, param: "") { (uuid, response, errorDesc) in
            if commandId == uuid {
                if let dict = response as? NSDictionary {
                    Lightning.parseTransactionsResult(channelId: channelId, scriptPubKey: scriptPubKey, txid: txid, dict: dict, completion: completion)
                } else {
                    completion((nil, errorDesc ?? "unknown error listing your lightning wallets transactions"))
                }
            }
        }
    }
    
    class func parseTransactionsResult(channelId: String, scriptPubKey: String, txid: String, dict: NSDictionary, completion: @escaping ((result: NSDictionary?, errorMessage: String?)) -> Void) {
        if let transactions = dict["transactions"] as? NSArray {
            for tx in transactions {
                if let txDict = tx as? NSDictionary {
                    if let hash = txDict["hash"] as? String {
                        if hash == txid {
                            if let outputs = txDict["outputs"] as? NSArray {
                                if outputs.count > 0 {
                                    for output in outputs {
                                        if let outputDict = output as? NSDictionary {
                                            if let spk = outputDict["scriptPubKey"] as? String {
                                                if spk == scriptPubKey {
                                                    if let vout = outputDict["index"] as? Int {
                                                        Lightning.fundchannelcomplete(channelId: channelId, txid: txid, vout: vout, completion: completion)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    class func fundchannelcomplete(channelId: String, txid: String, vout: Int, completion: @escaping ((result: NSDictionary?, errorMessage: String?)) -> Void) {
        let param = "\"\(channelId)\", \"\(txid)\", \(vout)"
        let commandId = UUID()
        LightningRPC.command(id: commandId, method: .fundchannel_complete, param: param) { (uuid, response, errorDesc) in
            if commandId == uuid {
                if let dict = response as? NSDictionary {
                    completion((dict, nil))
                } else {
                    completion((nil, errorDesc ?? "unknown error completing the channel funding"))
                }
            }
        }
    }
    
}
