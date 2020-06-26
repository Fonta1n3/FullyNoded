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
    
    class func loadWalletSection(completion: @escaping ((wallets: NSArray?, errorMessage: String?)) -> Void) {
        Reducer.makeCommand(command: .listwallets, param: "") { (response, errorMessage) in
            if let wallets = response as? NSArray {
                completion((wallets, nil))
            } else {
                if errorMessage != nil {
                    if errorMessage!.contains("Method not found") {
                        walletDisabled = true
                        completion((nil, "walletDisabled"))
                    } else {
                        completion((nil, errorMessage))
                    }
                } else {
                    walletDisabled = false
                    completion((nil, "error getting wallets"))
                }
            }
        }
    }
    
    class func loadSectionZero(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        if !walletDisabled {
            getBalance(completion: completion)
        } else {
            dictToReturn["coldBalance"] = "disabled"
            dictToReturn["unconfirmedBalance"] = "disabled"
            dictToReturn["hotBalance"] = "disabled"
            completion((dictToReturn, nil))
        }
    }
    
    class func getUnconfirmedBalance(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        Reducer.makeCommand(command: .getunconfirmedbalance, param: "") { (response, errorMessage) in
            if let unconfirmedBalance = response as? Double {
                parseUncomfirmedBalance(unconfirmedBalance: unconfirmedBalance)
                listUnspent(completion: completion)
            } else {
                completion((nil, errorMessage ?? ""))
            }
        }
    }
    
    class func getBalance(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        Reducer.makeCommand(command: .getbalance, param: "\"*\", 0, false") { (response, errorMessage) in
            if let balanceCheck = response as? Double {
                parseBalance(balance: balanceCheck)
                getUnconfirmedBalance(completion: completion)
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
    
    class func listUnspent(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        Reducer.makeCommand(command: .listunspent, param: "0") { (response, errorMessage) in
            if let utxos = response as? NSArray {
                parseUtxos(utxos: utxos)
                completion((dictToReturn, nil))
            } else {
                completion((nil, errorMessage ?? ""))
            }
        }
    }
    
    class func loadSectionOne(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        Reducer.makeCommand(command: .getblockchaininfo, param: "") { (response, errorMessage) in
            if let blockchainInfo = response as? NSDictionary {
                parseBlockchainInfo(blockchainInfo: blockchainInfo)
                getPeerInfo(completion: completion)
            } else {
                completion((nil, errorMessage ?? ""))
            }
        }
    }
    
    class func getPeerInfo(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        Reducer.makeCommand(command: .getpeerinfo, param: "") { (response, errorMessage) in
            if let peerInfo = response as? NSArray {
                parsePeerInfo(peerInfo: peerInfo)
                getNetworkInfo(completion: completion)
            } else {
                 completion((nil, errorMessage ?? ""))
            }
        }
    }
    
    class func getNetworkInfo(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        Reducer.makeCommand(command: .getnetworkinfo, param: "") { (response, errorMessage) in
            if let networkInfo = response as? NSDictionary {
                parseNetworkInfo(networkInfo: networkInfo)
                getMiningInfo(completion: completion)
            } else {
                completion((nil, errorMessage ?? ""))
            }
        }
    }
    
    class func getMiningInfo(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        Reducer.makeCommand(command: .getmininginfo, param: "") { (response, errorMessage) in
            if let miningInfo = response as? NSDictionary {
                parseMiningInfo(miningInfo: miningInfo)
                getUptime(completion: completion)
            } else {
                completion((nil, errorMessage ?? ""))
            }
        }
    }
    
    class func getUptime(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        Reducer.makeCommand(command: .uptime, param: "") { (response, errorMessage) in
            if let uptime = response as? Double {
                dictToReturn["uptime"] = Int(uptime)
                getMempoolInfo(completion: completion)
            } else {
                completion((nil, errorMessage ?? ""))
            }
        }
    }
    
    class func getMempoolInfo(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        Reducer.makeCommand(command: .getmempoolinfo, param: "") { (response, errorMessage) in
            if let dict = response as? NSDictionary {
                dictToReturn["mempoolCount"] = dict["size"] as! Int
                let feeRate = UserDefaults.standard.integer(forKey: "feeTarget")
                estimateSmartFee(feeRate: feeRate, completion: completion)
            } else {
                completion((nil, errorMessage ?? ""))
            }
        }
    }
    
    class func estimateSmartFee(feeRate: Int, completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
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
                    completion((arrayToReturn, nil))
                }
            }
        } else {
            arrayToReturn = []
            completion((arrayToReturn, nil))
        }
    }
    
    // MARK: Section 0 parsers
    
    class func parseBalance(balance: Double) {
        
        if balance == 0.0 {
            
            dictToReturn["hotBalance"] = "0.00000000"
            
        } else {
            
            dictToReturn["hotBalance"] = "\((round(100000000*balance)/100000000).avoidNotation)"
            
        }
        
    }
    
    class func parseUncomfirmedBalance(unconfirmedBalance: Double) {
        
        if unconfirmedBalance != 0.0 || unconfirmedBalance != 0 {
            
            dictToReturn["unconfirmedBalance"] = "unconfirmed \(unconfirmedBalance.avoidNotation)"
            
        } else {
            
            dictToReturn["unconfirmedBalance"] = "unconfirmed 0.00000000"
            
        }
        
    }
    
    class func parseUtxos(utxos: NSArray) {
        
        var amount = 0.0
        
        for utxo in utxos {
            
            let utxoDict = utxo as! NSDictionary
            let spendable = utxoDict["spendable"] as! Bool
            
            if !spendable {
                
                let balance = utxoDict["amount"] as! Double
                amount += balance
                
            }
            
        }
        
        if amount == 0.0 {
            
            dictToReturn["coldBalance"] = "0.00000000"
            
        } else {
            
            dictToReturn["coldBalance"] = "\(round(100000000*amount)/100000000)"
            
        }
        
    }
    
    // MARK: Section 1 parsers
    
    class func parseMiningInfo(miningInfo: NSDictionary) {
        
        let hashesPerSecond = miningInfo["networkhashps"] as! Double
        let exahashesPerSecond = hashesPerSecond / 1000000000000000000
        dictToReturn["networkhashps"] = Int(exahashesPerSecond).withCommas()
        
    }
    
    class func parseBlockchainInfo(blockchainInfo: NSDictionary) {
        
        if let currentblockheight = blockchainInfo["blocks"] as? Int {
            
            dictToReturn["blocks"] = currentblockheight
            
        }
        
        if let difficultyCheck = blockchainInfo["difficulty"] as? Double {
            
            dictToReturn["difficulty"] = "difficulty \(Int(difficultyCheck / 1000000000000).withCommas()) trillion"
            
        }
        
        if let sizeCheck = blockchainInfo["size_on_disk"] as? Int {
            
            dictToReturn["size"] = "\(sizeCheck/1000000000)gb blockchain"
            
        }
        
        if let progressCheck = blockchainInfo["verificationprogress"] as? Double {
            dictToReturn["actualProgress"] = progressCheck
            if progressCheck > 0.99 {
                dictToReturn["progress"] = "Fully verified"
            } else {
                dictToReturn["progress"] = "\(Int(progressCheck*100))% verified"
            }
        }
        
        if let chain = blockchainInfo["chain"] as? String {
            
            dictToReturn["chain"] = "\(chain) chain"
            UserDefaults.standard.set(chain, forKey: "chain")
            
        }
        
        if let pruned = blockchainInfo["pruned"] as? Bool {
            
            dictToReturn["pruned"] = pruned
            
        }
        
    }
    
    class func parsePeerInfo(peerInfo: NSArray) {
        
        var incomingCount = 0
        var outgoingCount = 0
        
        for peer in peerInfo {
            
            let peerDict = peer as! NSDictionary
            
            let incoming = peerDict["inbound"] as! Bool
            
            if incoming {
                
                incomingCount += 1
                dictToReturn["incomingCount"] = incomingCount
                
            } else {
                
                outgoingCount += 1
                dictToReturn["outgoingCount"] = outgoingCount
                
            }
            
        }
        
    }
    
    class func parseNetworkInfo(networkInfo: NSDictionary) {
        
        let subversion = (networkInfo["subversion"] as! String).replacingOccurrences(of: "/", with: "")
        dictToReturn["subversion"] = subversion.replacingOccurrences(of: "Satoshi:", with: "")
        
        let networks = networkInfo["networks"] as! NSArray
        
        for network in networks {
            
            let dict = network as! NSDictionary
            let name = dict["name"] as! String
            
            if name == "onion" {
                
                let reachable = dict["reachable"] as! Bool
                dictToReturn["reachable"] = reachable
                
            }
            
        }
        
    }
    
    class func parseTransactions(transactions: NSArray) {
        
        var transactionArray = [Any]()
        
        for item in transactions {
            
            if let transaction = item as? NSDictionary {
                
                var label = String()
                var replaced_by_txid = String()
                var isCold = false
                
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
                
                if let boolCheck = transaction["involvesWatchonly"] as? Bool {
                    
                    isCold = boolCheck
                    
                }
                
                transactionArray.append(["address": address,
                                         "amount": amountString,
                                         "confirmations": confirmations,
                                         "label": label,
                                         "date": dateString,
                                         "rbf": rbf,
                                         "txID": txID,
                                         "replacedBy": replaced_by_txid,
                                         "involvesWatchonly":isCold])
                
            }
            
        }
        
        arrayToReturn = transactionArray as! [[String:Any]]
        
    }
    
}
