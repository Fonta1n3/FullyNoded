//
//  Lightning.swift
//  FullyNoded
//
//  Created by Peter on 05/08/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

class Lightning {
        
    class func connect(amount: Int, id: String, ip: String?, port: String?, completion: @escaping ((result: [String:Any]?, errorMessage: String?)) -> Void) {
        print("connect")
        var param:[String:Any] = ["id":id]
        
        if let ip = ip {
            param["host"] = ip
        }
        
        if let port = port {
            param["port"] = port
        }
        
        let commandId = UUID()
        LightningRPC.sharedInstance.command(id: commandId, method: .connect, param: param) { (uuid, response, errorDesc) in
            if let dict = response as? [String:Any] {
                parseConnection(amount: amount, dict: dict, completion: completion)
            } else {
                completion((nil, errorDesc ?? "unknown error connecting to that node"))
            }
        }
    }
    
    class func parseConnection(amount: Int, dict: [String:Any], completion: @escaping ((result: [String:Any]?, errorMessage: String?)) -> Void) {
        if let id = dict["id"] as? String {
            Lightning.getClosingAddress(channelId: id, amount: amount, completion: completion)
        } else {
            completion((nil, "error parsing the connection result"))
        }
    }
    
    class func getClosingAddress(channelId: String, amount: Int, completion: @escaping ((result: [String:Any]?, errorMessage: String?)) -> Void) {
        activeWallet { wallet in
            guard let wallet = wallet else {
                completion((nil, "No active wallet, in order to create a channel you need to be using an active FN onchain wallet. This can be single sig, multisig, hot or cold. Funds will always be returned to this wallet when this channel closes. The channel will be funded directly from your active FN wallet."))
                return
            }
            let i = Int(wallet.index)
            let param:Derive_Addresses = .init(["descriptor":wallet.receiveDescriptor, "range": [i,i]])
            OnchainUtils.deriveAddresses(param: param) { (addresses, message) in
                guard let addresses = addresses as? NSArray, let address = addresses[0] as? String else {
                    completion((nil, "Error getting closing address: \(message ?? "unknown")"))
                    return
                }
                Lightning.fundchannelstart(channelId: channelId, amount: amount, address: address, completion: completion)
            }
        }
    }
    
    class func fundchannelstart(channelId: String, amount: Int, address: String, completion: @escaping ((result: [String:Any]?, errorMessage: String?)) -> Void) {
        let p = [
            "id":channelId,
            "amount": amount,
            "feerate": "normal",
            "announce": false,
            "close_to": address
        ] as [String:Any]
        
        let commandId = UUID()
        
        LightningRPC.sharedInstance.command(id: commandId, method: .fundchannel_start, param: p) { (uuid, response, errorDesc) in
            if let fundedChannelDict = response as? [String:Any] {
                Lightning.parseFundChannelStart(channelId: channelId, amount: amount, dict: fundedChannelDict, completion: completion)
            } else {
                completion((nil, errorDesc ?? "unknown error funding that channel"))
            }
        }
    }
    
    class func parseFundChannelStart(channelId: String, amount: Int, dict: [String:Any], completion: @escaping ((result: [String:Any]?, errorMessage: String?)) -> Void) {
        if let address = dict["funding_address"] as? String, let scriptPubKey = dict["scriptpubkey"] as? String {
            createFundingPsbt(channelId, scriptPubKey, address, amount, completion: completion)
        } else {
            completion((nil, "error parsing channel funding start"))
        }
    }
    
    class func createFundingPsbt(_ channelId: String,
                                 _ scriptPubKey: String,
                                 _ address: String,
                                 _ amount: Int, completion: @escaping ((result: [String:Any]?, errorMessage: String?)) -> Void) {
        
        let btcAmount = Double(rounded(number: Double(amount) / 100000000.0).avoidNotation)!
        
        CreatePSBT.create(inputs: [], outputs: [[address:btcAmount]]) { (psbt, rawTx, errorMessage) in
            guard errorMessage == nil else {
                completion((nil, "Error creating funding psbt: \(errorMessage ?? "unknown error")"))
                return
            }
            
            guard let psbt = psbt else {
                completion((nil, "no psbt returned..."))
                return
            }
                        
            UserDefaults.standard.setValue(scriptPubKey, forKey: "scriptPubKey")
            UserDefaults.standard.setValue(address, forKey: "address")
            UserDefaults.standard.setValue(amount, forKey: "amount")
            UserDefaults.standard.setValue(channelId, forKey: "channelId")
            
            completion((["psbt":psbt], nil))
        }
    }
    
    class func fundchannelcomplete(channelId: String, psbt: String, completion: @escaping ((result: [String:Any]?, errorMessage: String?)) -> Void) {
        let param:[String:Any] = ["id":channelId, "psbt": psbt]
        let commandId = UUID()
        
        LightningRPC.sharedInstance.command(id: commandId, method: .fundchannel_complete, param: param) { (uuid, response, errorDesc) in
            guard let dict = response as? [String:Any], let commitments_secured = dict["commitments_secured"] as? Bool, commitments_secured else {
                completion((nil, "Transaction not sent! Funding completion failed." + (errorDesc ?? "Unknown error completing the channel funding.")))
                return
            }
            completion((dict, errorDesc))
        }
    }
    
    class private func saveTx(memo: String, txid: String, completion: @escaping ((result: [String:Any]?, errorMessage: String?)) -> Void) {
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
