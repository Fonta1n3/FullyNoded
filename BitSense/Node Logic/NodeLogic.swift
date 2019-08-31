//
//  NodeLogic.swift
//  BitSense
//
//  Created by Peter on 26/08/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class NodeLogic {
    
    let dateFormatter = DateFormatter()
    
    var helper = SSHelper()
    var ssh:SSHService!
    var isUsingSSH = IsUsingSSH.sharedInstance
    var torClient:TorClient!
    var torRPC:MakeRPCCall!
    
    var errorBool = Bool()
    var errorDescription = ""
    
    var dictToReturn = [String:Any]()
    var arrayToReturn = [[String:Any]]()
    
    func loadSectionZero(completion: @escaping () -> Void) {
        print("loadSectionZero")
    
        func loadTableDataSsh(method: BTC_CLI_COMMAND, param: String) {
            
            if !self.isUsingSSH {
                
                //loadTableDataTor(method: method, param: param)
                
            } else {
                
                func getResult() {
                    print("get result")
                    
                    if !helper.errorBool {
                        
                        switch method {
                            
                        case BTC_CLI_COMMAND.listunspent:
                            
                            let utxos = helper.arrayToReturn
                            parseUtxos(utxos: utxos)
                            completion()
                            
                        case BTC_CLI_COMMAND.getunconfirmedbalance:
                            
                            let unconfirmedBalance = helper.doubleToReturn
                            parseUncomfirmedBalance(unconfirmedBalance: unconfirmedBalance)
                            
                            loadTableDataSsh(method: BTC_CLI_COMMAND.listunspent,
                                             param: "0")
                            
                        case BTC_CLI_COMMAND.getbalance:
                            
                            let balanceCheck = helper.doubleToReturn
                            parseBalance(balance: balanceCheck)
                            
                            loadTableDataSsh(method: BTC_CLI_COMMAND.getunconfirmedbalance,
                                             param: "")
                            
                        default:
                            
                            break
                            
                        }
                        
                    } else {
                        
                        if isWalletRPC(command: method) {
                            
                            print("wallet disabled")
                            
                            switch method {
                                
                            case BTC_CLI_COMMAND.getbalance:
                                
                                dictToReturn["hotBalance"] = 0.0
                                
                            case BTC_CLI_COMMAND.getunconfirmedbalance:
                                
                                dictToReturn["unconfirmedBalance"] = 0.0
                                
                            case BTC_CLI_COMMAND.listunspent:
                                
                                dictToReturn["utxos"] = []
                                
                            default:
                                
                                break
                                
                            }
                            
                            completion()
                            
                        } else {
                            
                            errorBool = true
                            errorDescription = helper.errorDescription + " " + ". Last command: \(method.rawValue)"
                            completion()
                            
                        }
                        
                    }
                    
                }
                
                if self.ssh != nil {
                    
                    if self.ssh.session.isAuthorized {
                        
                        if self.ssh.session.isConnected {
                            
                            self.helper.executeSSHCommand(ssh: self.ssh,
                                                          method: method,
                                                          param: param,
                                                          completion: getResult)
                            
                        } else {
                            
                            errorBool = true
                            errorDescription = "SSH not connected"
                            completion()
                            
                        }
                        
                    }
                    
                } else {
                    
                    errorBool = true
                    errorDescription = "SSH not connected"
                    completion()
                }
                
            }
            
        }
        
        loadTableDataSsh(method: BTC_CLI_COMMAND.getbalance,
                         param: "\"*\", 0, false")
    
    }
    
    func loadSectionOne(completion: @escaping () -> Void) {
        print("loadSectionOne")
        
        func loadTableDataSsh(method: BTC_CLI_COMMAND, param: String) {
            
            if !self.isUsingSSH {
                
                //loadTableDataTor(method: method, param: param)
                
            } else {
                
                func getResult() {
                    print("get result")
                    
                    if !helper.errorBool {
                        
                        switch method {
                            
                        case BTC_CLI_COMMAND.getmempoolinfo:
                            
                            let dict = helper.dictToReturn
                            dictToReturn["mempoolCount"] = dict["size"] as! Int
                            completion()
                            
                        case BTC_CLI_COMMAND.uptime:
                            
                            dictToReturn["uptime"] = Int(helper.doubleToReturn)
                            
                            loadTableDataSsh(method: BTC_CLI_COMMAND.getmempoolinfo,
                                             param: "")
                            
                            
                        case BTC_CLI_COMMAND.getmininginfo:
                            
                            let miningInfo = helper.dictToReturn
                            parseMiningInfo(miningInfo: miningInfo)
                            
                            loadTableDataSsh(method: BTC_CLI_COMMAND.uptime,
                                             param: "")
                            
                        case BTC_CLI_COMMAND.getnetworkinfo:
                            
                            let networkInfo = helper.dictToReturn
                            parseNetworkInfo(networkInfo: networkInfo)
                            
                            loadTableDataSsh(method: BTC_CLI_COMMAND.getmininginfo,
                                             param: "")
                            
                        case BTC_CLI_COMMAND.getpeerinfo:
                            
                            let peerInfo = helper.arrayToReturn
                            parsePeerInfo(peerInfo: peerInfo)
                            
                            loadTableDataSsh(method: BTC_CLI_COMMAND.getnetworkinfo,
                                             param: "")
                            
                        case BTC_CLI_COMMAND.getblockchaininfo:
                            
                            let blockchainInfo = helper.dictToReturn
                            parseBlockchainInfo(blockchainInfo: blockchainInfo)
                            
                            loadTableDataSsh(method: BTC_CLI_COMMAND.getpeerinfo,
                                             param: "")
                            
                        default:
                            
                            break
                            
                        }
                        
                    }
                    
                }
                
                if self.ssh != nil {
                    
                    if self.ssh.session.isAuthorized {
                        
                        if self.ssh.session.isConnected {
                            
                            self.helper.executeSSHCommand(ssh: self.ssh,
                                                          method: method,
                                                          param: param,
                                                          completion: getResult)
                            
                        } else {
                            
                            errorBool = true
                            errorDescription = "SSH not connected"
                            completion()
                            
                        }
                        
                    }
                    
                } else {
                    
                    errorBool = true
                    errorDescription = "SSH not connected"
                    completion()
                    
                }
                
            }
         
        }
        
        loadTableDataSsh(method: BTC_CLI_COMMAND.getblockchaininfo,
                         param: "")
        
    }
    
    func loadSectionTwo(completion: @escaping () -> Void) {
        print("loadSectionTwo")
        
        func loadTableDataSsh(method: BTC_CLI_COMMAND, param: String) {
            
            if !self.isUsingSSH {
                
                //loadTableDataTor(method: method, param: param)
                
            } else {
                
                func getResult() {
                    print("get result")
                    
                    if !helper.errorBool {
                        
                        switch method {
                            
                        case BTC_CLI_COMMAND.listtransactions:
                            
                            let transactions = helper.arrayToReturn
                            parseTransactions(transactions: transactions)
                            completion()
                            
                            
                        default:
                            
                            break
                            
                        }
                        
                    } else {
                        
                        if isWalletRPC(command: method) {
                            
                            //its a wallet command skip incase wallet is disabled
                            print("wallet disabled")
                            
                            switch method {
                                
                            case BTC_CLI_COMMAND.listtransactions:
                                
                                dictToReturn["transactions"] = []
                                completion()
                                
                            default:
                                
                                break
                                
                            }
                            
                        } else {
                            
                            errorBool = true
                            errorDescription = helper.errorDescription + " " + ". Last command: \(method.rawValue)"
                            completion()
                            
                        }
                        
                    }
                    
                }
                
                if self.ssh != nil {
                    
                    if self.ssh.session.isAuthorized {
                        
                        if self.ssh.session.isConnected {
                            
                            self.helper.executeSSHCommand(ssh: self.ssh,
                                                          method: method,
                                                          param: param,
                                                          completion: getResult)
                            
                        } else {
                            
                            errorBool = true
                            errorDescription = "SSH not connected"
                            completion()
                            
                        }
                        
                    }
                    
                } else {
                    
                    errorBool = true
                    errorDescription = "SSH not connected"
                    completion()
                    
                }
                
            }
            
        }
        
        loadTableDataSsh(method: BTC_CLI_COMMAND.listtransactions,
                         param: "\"*\", 50, 0, true")
        
    }
    
    // MARK: Section 0 parsers
    
    func parseBalance(balance: Double) {
        
        if balance == 0.0 {
            
            dictToReturn["hotBalance"] = "0.00000000"
            
        } else {
            
            dictToReturn["hotBalance"] = "\(round(100000000*balance)/100000000)"
            
        }
        
    }
    
    func parseUncomfirmedBalance(unconfirmedBalance: Double) {
        
        if unconfirmedBalance != 0.0 || unconfirmedBalance != 0 {
            
            dictToReturn["unconfirmedBalance"] = "unconfirmed \(unconfirmedBalance.avoidNotation)"
            
        } else {
            
            dictToReturn["unconfirmedBalance"] = "unconfirmed 0.00000000"
            
        }
        
    }
    
    func parseUtxos(utxos: NSArray) {
        
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
            
            dictToReturn["coldBalance"] = "0.0000000"
            
        } else {
            
            dictToReturn["coldBalance"] = "\(round(100000000*amount)/100000000)"
            
        }
        
    }
    
    // MARK: Section 1 parsers
    
    func parseMiningInfo(miningInfo: NSDictionary) {
        
                dictToReturn["networkhashps"] = (miningInfo["networkhashps"] as! Double).withCommas()
        
    }
    
    func parseBlockchainInfo(blockchainInfo: NSDictionary) {
        
        if let currentblockheight = blockchainInfo["blocks"] as? Int {
            
            dictToReturn["blocks"] = currentblockheight
            
        }
        
        if let difficultyCheck = blockchainInfo["difficulty"] as? Double {
            
            dictToReturn["difficulty"] = "\(difficultyCheck)"
            
        }
        
        if let sizeCheck = blockchainInfo["size_on_disk"] as? Int {
            
            dictToReturn["size"] = "\(sizeCheck/1000000000) gigabytes"
            
        }
        
        if let progressCheck = blockchainInfo["verificationprogress"] as? Double {
            
            dictToReturn["progress"] = "\(Int(progressCheck*100))%"
            
        }
        
        if let chain = blockchainInfo["chain"] as? String {
            
            dictToReturn["chain"] = chain
            
        }
        
        if let pruned = blockchainInfo["pruned"] as? Bool {
            
            dictToReturn["pruned"] = pruned
            
        }
        
    }
    
    func parsePeerInfo(peerInfo: NSArray) {
        
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
    
    func parseNetworkInfo(networkInfo: NSDictionary) {
        
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
    
    func parseTransactions(transactions: NSArray) {
        
        var transactionArray = [Any]()
        
        for item in transactions {
            
            if let transaction = item as? NSDictionary {
                
                var label = String()
                var replaced_by_txid = String()
                var isCold = false
                
                let address = transaction["address"] as! String
                let amount = transaction["amount"] as! Double
                let amountString = amount.avoidNotation
                let confirmations = String(transaction["confirmations"] as! Int)
                
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
                
                let secondsSince = transaction["time"] as! Double
                let rbf = transaction["bip125-replaceable"] as! String
                let txID = transaction["txid"] as! String
                
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
