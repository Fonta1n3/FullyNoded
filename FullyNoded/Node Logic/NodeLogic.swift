//
//  NodeLogic.swift
//  BitSense
//
//  Created by Peter on 26/08/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class NodeLogic {
    
    static let dateFormatter = DateFormatter()
    static var dictToReturn = [String:Any]()
    static var arrayToReturn = [[String:Any]]()
    static var walletDisabled = Bool()
    
    class func loadBalances(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        if !walletDisabled {
            listUnspent(completion: completion)
        } else {
            dictToReturn["unconfirmedBalance"] = "disabled"
            dictToReturn["onchainBalance"] = "disabled"
            completion((dictToReturn, nil))
        }
    }
    
//    class func getUnconfirmedBalance(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
//        Reducer.makeCommand(command: .getunconfirmedbalance, param: "") { (response, errorMessage) in
//            if let unconfirmedBalance = response as? Double {
//                parseUncomfirmedBalance(unconfirmedBalance: unconfirmedBalance)
//                listUnspent(completion: completion)
//            } else {
//                completion((nil, errorMessage ?? ""))
//            }
//        }
//    }
    
//    class func getBalance(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
//        Reducer.makeCommand(command: .getbalance, param: "\"*\", 0, false") { (response, errorMessage) in
//            if let balanceCheck = response as? Double {
//                parseBalance(balance: balanceCheck)
//                getUnconfirmedBalance(completion: completion)
//            } else if errorMessage != nil {
//                if errorMessage!.contains("Method not found") {
//                    walletDisabled = true
//                    completion((nil, "wallet disabled"))
//                } else {
//                    completion((nil, errorMessage ?? ""))
//                }
//            }
//        }
//    }
    
    class func listUnspent(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        Reducer.makeCommand(command: .listunspent, param: "0") { (response, errorMessage) in
            if let utxos = response as? NSArray {
                parseUtxos(utxos: utxos)
                getOffChainBalance(completion: completion)
            } else if errorMessage != nil {
                if errorMessage!.contains("Method not found") {
                    walletDisabled = true
                    completion((nil, "wallet disabled"))
                } else {
                    completion((nil, errorMessage ?? ""))
                }
            }
        }
    }
    
    class func getOffChainBalance(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        let rpc = LightningRPC.sharedInstance
        rpc.command(method: .listfunds, param: "") { (response, errorDesc) in
            if let dict = response as? NSDictionary {
                if let outputs = dict["outputs"] as? NSArray {
                    if outputs.count > 0 {
                        var offchainBalance = 0.0
                        for (i, output) in outputs.enumerated() {
                            if let outputDict = output as? NSDictionary {
                                if let sats = outputDict["value"] as? Int {
                                    print("sats: \(sats)")
                                    let btc = Double(sats) / 100000000.0
                                    print("btc: \(btc)")
                                    offchainBalance += btc
                                }
                            }
                            if i + 1 == outputs.count {
                                print("offchainBalance: \(offchainBalance)")
                                dictToReturn["offchainBalance"] = "\(rounded(number: offchainBalance))"
                                completion((dictToReturn, nil))
                            }
                        }
                    } else {
                        dictToReturn["offchainBalance"] = "0.00000000"
                        completion((dictToReturn, errorDesc ?? ""))
                    }
                } else {
                    dictToReturn["offchainBalance"] = "0.00000000"
                    completion((dictToReturn, errorDesc ?? ""))
                }
            } else {
                dictToReturn["offchainBalance"] = "0.00000000"
                completion((dictToReturn, errorDesc ?? ""))
            }
        }
    }
    
    class func loadBlockchainInfo(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        Reducer.makeCommand(command: .getblockchaininfo, param: "") { (response, errorMessage) in
            if let blockchainInfo = response as? NSDictionary {
                parseBlockchainInfo(blockchainInfo: blockchainInfo, completion: completion)
            } else {
                completion((nil, errorMessage ?? ""))
            }
        }
    }
    
    class func getPeerInfo(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        Reducer.makeCommand(command: .getpeerinfo, param: "") { (response, errorMessage) in
            if let peerInfo = response as? NSArray {
                parsePeerInfo(peerInfo: peerInfo, completion: completion)
            } else {
                 completion((nil, errorMessage ?? ""))
            }
        }
    }
    
    class func getNetworkInfo(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        Reducer.makeCommand(command: .getnetworkinfo, param: "") { (response, errorMessage) in
            if let networkInfo = response as? NSDictionary {
                parseNetworkInfo(networkInfo: networkInfo, completion: completion)
            } else {
                completion((nil, errorMessage ?? ""))
            }
        }
    }
    
    class func getMiningInfo(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        Reducer.makeCommand(command: .getmininginfo, param: "") { (response, errorMessage) in
            if let miningInfo = response as? NSDictionary {
                parseMiningInfo(miningInfo: miningInfo, completion: completion)
            } else {
                completion((nil, errorMessage ?? ""))
            }
        }
    }
    
    class func getUptime(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        Reducer.makeCommand(command: .uptime, param: "") { (response, errorMessage) in
            if let uptime = response as? Double {
                var toReturn = [String:Any]()
                toReturn["uptime"] = Int(uptime)
                completion((toReturn, nil))
            } else {
                completion((nil, errorMessage ?? ""))
            }
        }
    }
    
    class func getMempoolInfo(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        Reducer.makeCommand(command: .getmempoolinfo, param: "") { (response, errorMessage) in
            if let dict = response as? NSDictionary {
                var mempoolInfo = [String:Any]()
                mempoolInfo["mempoolCount"] = dict["size"] as! Int
                completion((mempoolInfo, nil))
            } else {
                completion((nil, errorMessage ?? ""))
            }
        }
    }
    
    class func estimateSmartFee(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        let feeRate = UserDefaults.standard.integer(forKey: "feeTarget")
        Reducer.makeCommand(command: .estimatesmartfee, param: "\(feeRate)") { (response, errorMessage) in
            if let result = response as? NSDictionary {
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
    
    class func loadSectionTwo(completion: @escaping ((response: [[String:Any]]?, errorMessage: String?)) -> Void) {
        if !walletDisabled {
            Reducer.makeCommand(command: .listtransactions, param: "\"*\", 50, 0, true") { (response, errorMessage) in
                if let transactions = response as? NSArray {
                    parseTransactions(transactions: transactions)
                    //completion((arrayToReturn, nil))
                    getOffchainTransactions(completion: completion)
                }
            }
        } else {
            arrayToReturn = []
            completion((arrayToReturn, nil))
        }
    }
    
    class func getOffchainTransactions(completion: @escaping ((response: [[String:Any]]?, errorMessage: String?)) -> Void) {
        let rpc = LightningRPC.sharedInstance
        rpc.command(method: .listtransactions, param: "") { (response, errorDesc) in
            if let dict = response as? NSDictionary {
                if let transactions = dict["transactions"] as? NSArray {
                    for (t, transaction) in transactions.enumerated() {
                        if let txDict = transaction as? NSDictionary {
                            if let hash = txDict["hash"] as? String {
                                for (o, onchainTx) in arrayToReturn.enumerated() {
                                    if onchainTx["txID"] as! String == hash {
                                        arrayToReturn[o]["isLightning"] = true
                                    }
                                }
                            }
                            if t + 1 == transactions.count {
                                completion((arrayToReturn, nil))
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: Section 0 parsers
    
//    class func parseBalance(balance: Double) {
//
//        if balance == 0.0 {
//
//            dictToReturn["hotBalance"] = "0.00000000"
//
//        } else {
//
//            dictToReturn["hotBalance"] = "\((round(100000000*balance)/100000000).avoidNotation)"
//
//        }
//
//    }
    
    class func parseUncomfirmedBalance(unconfirmedBalance: Double) {
        
        if unconfirmedBalance != 0.0 || unconfirmedBalance != 0 {
            
            dictToReturn["unconfirmedBalance"] = "unconfirmed \(unconfirmedBalance.avoidNotation)"
            
        } else {
            
            dictToReturn["unconfirmedBalance"] = "unconfirmed 0.00000000"
            
        }
        
    }
    
    class func parseUtxos(utxos: NSArray) {
        
        var amount = 0.0
        var indexArray = [Int]()
        
        for (x, utxo) in utxos.enumerated() {
            
            let utxoDict = utxo as! NSDictionary
            let balance = utxoDict["amount"] as! Double
            amount += balance
            if let desc = utxoDict["desc"] as? String {
                let p = DescriptorParser()
                let str = p.descriptor(desc)
                var paths:[String]!
                if str.isMulti {
                    paths = str.derivationArray
                } else {
                    paths = [str.derivation]
                }
                for path in paths {
                    let arr = path.split(separator: "/")
                    for (i, comp) in arr.enumerated() {
                        if i + 1 == arr.count {
                            if let int = Int(comp) {
                                indexArray.append(int)
                            }
                        }
                    }
                }
            }
            if x + 1 == utxos.count {
                activeWallet { wallet in
                    if wallet != nil {
                        if indexArray.count > 0 {
                            let maxIndex = indexArray.reduce(Int.min, { max($0, $1) })
                            if wallet!.index < maxIndex {
                                CoreDataService.update(id: wallet!.id, keyToUpdate: "index", newValue: Int64(maxIndex), entity: .wallets) { success in
                                    if success {
                                        print("updated index from utxo")
                                    } else {
                                        print("failed to update index from utxo")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        if amount == 0.0 {
            
            dictToReturn["onchainBalance"] = "0.00000000"
            
        } else {
            
            dictToReturn["onchainBalance"] = "\(round(100000000*amount)/100000000)"
            
        }
        
    }
    
    // MARK: Section 1 parsers
    
    class func parseMiningInfo(miningInfo: NSDictionary, completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        var miningInfoToReturn = [String:Any]()
        let hashesPerSecond = miningInfo["networkhashps"] as! Double
        let exahashesPerSecond = hashesPerSecond / 1000000000000000000
        miningInfoToReturn["networkhashps"] = Int(exahashesPerSecond).withCommas()
        completion((miningInfoToReturn, nil))
    }
    
    class func parseBlockchainInfo(blockchainInfo: NSDictionary, completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        
        var blockchainInfoToReturn = [String:Any]()
        
        if let currentblockheight = blockchainInfo["blocks"] as? Int {
            
            blockchainInfoToReturn["blocks"] = currentblockheight
            
        }
        
        if let difficultyCheck = blockchainInfo["difficulty"] as? Double {
            
            blockchainInfoToReturn["difficulty"] = "difficulty \(Int(difficultyCheck / 1000000000000).withCommas()) trillion"
            
        }
        
        if let sizeCheck = blockchainInfo["size_on_disk"] as? Int {
            
            blockchainInfoToReturn["size"] = "\(sizeCheck/1000000000)gb blockchain"
            
        }
        
        if let progressCheck = blockchainInfo["verificationprogress"] as? Double {
            blockchainInfoToReturn["actualProgress"] = progressCheck
            if progressCheck > 0.9999 {
                blockchainInfoToReturn["progress"] = "Fully verified"
            } else {
                blockchainInfoToReturn["progress"] = "\(Int(progressCheck*100))% verified"
            }
        }
        
        if let chain = blockchainInfo["chain"] as? String {
            blockchainInfoToReturn["chain"] = "\(chain) chain"
            UserDefaults.standard.set(chain, forKey: "chain")
            
        }
        
        if let pruned = blockchainInfo["pruned"] as? Bool {
            blockchainInfoToReturn["pruned"] = pruned
            
        }
        
        completion((blockchainInfoToReturn, nil))
        
    }
    
    class func parsePeerInfo(peerInfo: NSArray, completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        
        var peerInfoToReturn = [String:Any]()
        var incomingCount = 0
        var outgoingCount = 0
        
        for peer in peerInfo {
            
            let peerDict = peer as! NSDictionary
            
            let incoming = peerDict["inbound"] as! Bool
            
            if incoming {
                
                incomingCount += 1
                peerInfoToReturn["incomingCount"] = incomingCount
                
            } else {
                
                outgoingCount += 1
                peerInfoToReturn["outgoingCount"] = outgoingCount
                
            }
            
        }
        completion((peerInfoToReturn, nil))
        
    }
    
    class func parseNetworkInfo(networkInfo: NSDictionary, completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        
        var networkInfoToReturn = [String:Any]()
        let subversion = (networkInfo["subversion"] as! String).replacingOccurrences(of: "/", with: "")
        networkInfoToReturn["subversion"] = subversion.replacingOccurrences(of: "Satoshi:", with: "")
        
        let networks = networkInfo["networks"] as! NSArray
        
        for network in networks {
            
            let dict = network as! NSDictionary
            let name = dict["name"] as! String
            
            if name == "onion" {
                
                let reachable = dict["reachable"] as! Bool
                networkInfoToReturn["reachable"] = reachable
                
            }
            
        }
        completion((networkInfoToReturn, nil))
        
    }
    
    class func parseTransactions(transactions: NSArray) {
        
        var transactionArray = [[String:Any]]()
        
        for item in transactions {
            
            if let transaction = item as? NSDictionary {
                
                var label = String()
                var replaced_by_txid = String()
                
                let address = transaction["address"] as? String ?? ""
                let amount = transaction["amount"] as? Double ?? 0.0
                let amountString = amount.avoidNotation
                let confsCheck = transaction["confirmations"] as? Int ?? 0
                let confirmations = String(confsCheck)
                
                if let replaced_by_txid_check = transaction["replaced_by_txid"] as? String {
                    
                    replaced_by_txid = replaced_by_txid_check
                    
                }
                
                if let labelCheck = transaction["label"] as? String {
                    
                    label = labelCheck
                    
                    if labelCheck == "" {
                        
                        label = ""
                        
                    }
                    
                    if labelCheck == "," {
                        
                        label = ""
                        
                    }
                    
                } else {
                    
                    label = ""
                    
                }
                
                let secondsSince = transaction["time"] as? Double ?? 0.0
                let rbf = transaction["bip125-replaceable"] as? String ?? ""
                let txID = transaction["txid"] as? String ?? ""
                
                let date = Date(timeIntervalSince1970: secondsSince)
                dateFormatter.dateFormat = "MMM-dd-yyyy HH:mm"
                let dateString = dateFormatter.string(from: date)
                
                transactionArray.append(["address": address,
                                         "amount": amountString,
                                         "confirmations": confirmations,
                                         "label": label,
                                         "date": dateString,
                                         "rbf": rbf,
                                         "txID": txID,
                                         "replacedBy": replaced_by_txid,
                                         "selfTransfer":false,
                                         "remove":false,
                                         "onchain":true,
                                         "isLightning":false
                ])
                
            }
            
        }
        
        for (i, tx) in transactionArray.enumerated() {
            if let _ = tx["amount"] as? String {
                if let amount = Double(tx["amount"] as! String) {
                    if let txID = tx["txID"] as? String {
                        for (x, transaction) in transactionArray.enumerated() {
                            if let amountToCompare = Double(transaction["amount"] as! String) {
                                if x != i && txID == (transaction["txID"] as! String) {
                                    if amount + amountToCompare == 0 && amount > 0 {
                                        transactionArray[i]["selfTransfer"] = true
                                        
                                    } else if amount + amountToCompare == 0 && amount < 0 {
                                        transactionArray[i]["remove"] = true
                                        
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        arrayToReturn.removeAll()
        for tx in transactionArray {
            if let remove = tx["remove"] as? Bool {
                if !remove {
                    arrayToReturn.append(tx)
                    
                }
            }
        }
    }
    
}
