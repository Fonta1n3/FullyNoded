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
    static var offchainTxids:[String] = []
    
    class func loadBalances(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        if !walletDisabled {
            getLightningBalances(completion: completion)
        } else {
            dictToReturn["unconfirmedBalance"] = "disabled"
            dictToReturn["onchainBalance"] = "disabled"
            completion((dictToReturn, nil))
        }
    }
    
    class func getLightningBalances(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        CoreDataService.retrieveEntity(entityName: .newNodes) { nodes in
            guard let nodes = nodes else { return }
            
            var activeLightningNode = false
            
            for (i, node) in nodes.enumerated() {
                let nodeStr = NodeStruct(dictionary: node)
                
                if nodeStr.isLightning && nodeStr.isActive {
                    activeLightningNode = true
                    getOffChainBalanceLND(completion: completion)
                    break
                }
                
                if i + 1 == nodes.count && !activeLightningNode {
                    dictToReturn["offchainBalance"] = "0.00000000"
                    completion((dictToReturn, nil))
                }
            }
        }
    }
    
    class func getOffChainBalanceLND(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        let lnd = LndRpc.sharedInstance
        
        lnd.command(.channelbalance, nil, nil, nil) { (response, error) in
            guard let dict = response,
                  let localBalance = dict["local_balance"] as? [String:Any] else {
                dictToReturn["offchainBalance"] = "0.00000000"
                completion((dictToReturn, error ?? ""))
                return
            }
            
            let localBalanceSats = localBalance["sat"] as! String
            
            lnd.command(.walletbalance, nil, nil, nil) { (response, error) in
                guard let dict = response,
                      let walletBalance = dict["total_balance"] as? String else {
                    dictToReturn["offchainBalance"] = localBalanceSats
                    completion((dictToReturn, error ?? ""))
                    return
                }
                
                let total = Int(localBalanceSats)! + Int(walletBalance)!
                let btc = Double(total) / 100000000.0
                let roundedBalance = rounded(number: btc).avoidNotation
                dictToReturn["offchainBalance"] = "\(roundedBalance)"
                completion((dictToReturn, error ?? ""))
            }
        }
    }
    
    class func getPeerInfo(completion: @escaping ((response: GetPeerInfoResponse?, errorMessage: String?)) -> Void) {
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getpeerinfo) { (response, errorMessage) in
            if let peerInfo = response as? NSArray {
                parsePeerInfo(peerInfo: peerInfo, completion: completion)
            } else {
                 completion((nil, errorMessage ?? ""))
            }
        }
    }
    
    class func getNetworkInfo(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getnetworkinfo) { (response, errorMessage) in
            if let networkInfo = response as? [String:Any] {
                parseNetworkInfo(networkInfo: networkInfo, completion: completion)
            } else {
                completion((nil, errorMessage ?? ""))
            }
        }
    }
    
    class func getMiningInfo(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getmininginfo) { (response, errorMessage) in
            if let miningInfo = response as? [String:Any] {
                parseMiningInfo(miningInfo: miningInfo, completion: completion)
            } else {
                completion((nil, errorMessage ?? ""))
            }
        }
    }
    
    class func getUptime(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
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
    
    class func getMempoolInfo(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
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
    
    class func estimateSmartFee(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        let feeRate = UserDefaults.standard.integer(forKey: "feeTarget")
        let param:Estimate_Smart_Fee_Param = .init(["conf_target":feeRate])
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
    
    class func listOnchainTransactions(completion: @escaping ((response: ListTransactionsResponse?, errorMessage: String?)) -> Void) {
        guard !walletDisabled else {
            completion((nil, "Wallet is disabled."))
            return
        }
        let param:List_Transactions = .init(["count": 100])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .listtransactions(param)) { (response, errorMessage) in
            guard let response = response as? NSArray else {
                completion((nil, errorMessage ?? "Unable to cast listransactions rsponse as an NSArray."))
                return
            }
            
            guard let listTransactionsResponse = try? ListTransactionsResponse(from: response) else {
                completion((nil, "Failed parsing listtransactions response."))
                return
            }
            
            completion((listTransactionsResponse, nil))
        }
        
    }
    
    class func loadSectionTwo(completion: @escaping ((response: [[String:Any]]?, errorMessage: String?)) -> Void) {
        guard !walletDisabled else {
            arrayToReturn = []
            completion((arrayToReturn, nil))
            return
        }
        let param:List_Transactions = .init(["count": 100])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .listtransactions(param)) { (response, errorMessage) in
            if let transactions = response as? NSArray {
                parseTransactions(transactions: transactions)
            }
            isLndNode { isLndNode in
                guard isLndNode else {
                    arrayToReturn = arrayToReturn.sorted{ ($0["confirmations"] as! Int) < ($1["confirmations"] as! Int) }
                    completion((arrayToReturn, errorMessage))
                    return
                }
                getLNDTransactions(completion: completion)
            }
        }
    }
    
    private class func getLNDTransactions(completion: @escaping ((response: [[String:Any]]?, errorMessage: String?)) -> Void) {
        
        LndRpc.sharedInstance.command(.gettransactions, nil, nil, nil) { (response, error) in
            guard let dict = response, let transactions = dict["transactions"] as? NSArray, transactions.count > 0 else {
                arrayToReturn = arrayToReturn.sorted{ ($0["sortDate"] as? Date ?? Date()) > ($1["sortDate"] as? Date ?? Date()) }
                getPaidLND(completion: completion)
                return
            }
            
            for (t, transaction) in transactions.enumerated() {
                guard let txDict = transaction as? [String:Any], let hash = txDict["tx_hash"] as? String else {
                    arrayToReturn = arrayToReturn.sorted{ ($0["sortDate"] as? Date ?? Date()) > ($1["sortDate"] as? Date ?? Date()) }
                    getPaidLND(completion: completion)
                    return
                }
                
                let amountSat = (txDict["amount"] as? String ?? "0")!.replacingOccurrences(of: "-", with: "")
                let confs = txDict["num_confirmations"] as? Int ?? 0
                let label = txDict["label"] as? String ?? ""
                let time_stamp = txDict["time_stamp"] as? String ?? "0"
                let dest_addresses = txDict["dest_addresses"] as? NSArray ?? []
                
                var addresses = ""
                
                for address in dest_addresses {
                    addresses += (address as! String) + ", "
                }
                
                let date = Date(timeIntervalSince1970: Double(time_stamp)!)
                dateFormatter.dateFormat = "MMM-dd-yyyy HH:mm"
                let dateString = dateFormatter.string(from: date)
                
                let amountBtc = amountSat.doubleValue.satsToBtcDouble
                let fxRate = UserDefaults.standard.object(forKey: "fxRate") as? Double ?? 0.0
                let amountFiat = (amountBtc * fxRate).balanceText
                
                arrayToReturn.append(["address": addresses,
                                      "amountSats": "\(amountSat)",
                                      "amountFiat": amountFiat,
                                      "amountBtc": amountBtc.btcBalanceWithSpaces,
                                      "confirmations": "\(confs)",
                                      "label": label,
                                      "date": dateString,
                                      "rbf": false,
                                      "txID": hash,
                                      "replacedBy": "",
                                      "selfTransfer":false,
                                      "remove":false,
                                      "onchain":true,
                                      "isLightning":true,
                                      "sortDate":date])
                
                for (o, onchainTx) in arrayToReturn.enumerated() {
                    if onchainTx["txID"] as! String == hash {
                        arrayToReturn[o]["isLightning"] = true
                    }
                    
                    if t + 1 == transactions.count && o + 1 == arrayToReturn.count {
                        arrayToReturn = arrayToReturn.sorted{ ($0["sortDate"] as? Date ?? Date()) > ($1["sortDate"] as? Date ?? Date()) }
                        getPaidLND(completion: completion)
                    }
                }
            }
        }
    }
    
    class func getPaidLND(completion: @escaping ((response: [[String:Any]]?, errorMessage: String?)) -> Void) {
        let lnd = LndRpc.sharedInstance
        
        lnd.command(.listinvoices, nil, nil, ["reversed":true, "num_max_invoices": "100"]) { (response, error) in
            
            guard let paidInvoices = response?["invoices"] as? [[String:Any]], paidInvoices.count > 0 else {
                arrayToReturn = arrayToReturn.sorted{ ($0["sortDate"] as? Date ?? Date()) > ($1["sortDate"] as? Date ?? Date()) }
                getOutgoingPaymentsLND(completion: completion)
                return
            }
            
            CoreDataService.retrieveEntity(entityName: .transactions) { savedTxs in
                
                for (i, invoice) in paidInvoices.enumerated() {
                    var alreadySaved = false
                    let r_hash = invoice["r_hash"] as? String ?? ""
                    let data = Data(base64Encoded: r_hash)
                    let txid = data!.hexString
                    let amt_paid_sat = Int(invoice["amt_paid_sat"] as? String ?? "")!.withCommas
                    let payment_request = invoice["payment_request"] as? String ?? ""
                    let paid_at = invoice["settle_date"] as? String ?? ""
                    let settled = invoice["settled"] as! Bool
                    
                    if settled {
                        let date = Date(timeIntervalSince1970: Double(paid_at)!)
                        dateFormatter.dateFormat = "MMM-dd-yyyy HH:mm"
                        let dateString = dateFormatter.string(from: date)
                        
                        let amountBtc = amt_paid_sat.satsToBtc.btcBalanceWithSpaces
                        let fxRate = UserDefaults.standard.object(forKey: "fxRate") as? Double ?? 0.0
                        let amountFiat = (amountBtc.doubleValue * fxRate).balanceText
                        
                        arrayToReturn.append([
                                                "address": payment_request,
                                                "amountSats": "\(amt_paid_sat)",
                                                "amountBtc": amountBtc,
                                                "amountFiat": amountFiat,
                                                "confirmations": "paid",
                                                "label": "",
                                                "date": dateString,
                                                "rbf": false,
                                                "txID": txid,
                                                "replacedBy": "",
                                                "selfTransfer":false,
                                                "remove":false,
                                                "onchain":false,
                                                "isLightning":true,
                                                "sortDate":date])
                        
                        guard let savedTxs = savedTxs else {
                            saveLocally(txid: txid, date: date)
                            
                            if i + 1 == paidInvoices.count {
                                arrayToReturn = arrayToReturn.sorted{ ($0["sortDate"] as? Date ?? Date()) > ($1["sortDate"] as? Date ?? Date()) }
                                getOutgoingPaymentsLND(completion: completion)
                            }
                            
                            return
                        }
                        
                        for (s, savedTx) in savedTxs.enumerated() {
                            let savedTxStruct = TransactionStruct(dictionary: savedTx)
                            
                            if savedTxStruct.txid == txid {
                                alreadySaved = true
                            }
                            
                            if s + 1 == savedTxs.count {
                                if !alreadySaved {
                                    saveLocally(txid: txid, date: date)
                                }
                            }
                        }
                    }
                    
                    if i + 1 == paidInvoices.count {
                        arrayToReturn = arrayToReturn.sorted{ ($0["sortDate"] as? Date ?? Date()) > ($1["sortDate"] as? Date ?? Date()) }
                        getOutgoingPaymentsLND(completion: completion)
                    }
                }
            }
        }
    }
    
    private class func saveLocally(txid: String, date: Date) {
        let dict = [
            "txid":txid,
            "id":UUID(),
            "memo":"no transaction memo",
            "date":date,
            "label":""
        ] as [String:Any]

        CoreDataService.saveEntity(dict: dict, entityName: .transactions) { _ in }
    }
    
    class func getOutgoingPaymentsLND(completion: @escaping ((response: [[String:Any]]?, errorMessage: String?)) -> Void) {
        let lnd = LndRpc.sharedInstance
        
        let param:[String:Any] = ["include_incomplete":false]
        
        lnd.command(.listpayments, param, nil, nil) { (response, error) in
            guard let payments = response?["payments"] as? [[String:Any]], payments.count > 0 else {
                arrayToReturn = arrayToReturn.sorted{ ($0["sortDate"] as? Date ?? Date()) > ($1["sortDate"] as? Date ?? Date()) }
                completion((arrayToReturn, nil))
                return
            }
            
            CoreDataService.retrieveEntity(entityName: .transactions) { savedTxs in
                
                for (p, payment) in payments.enumerated() {
                    var alreadySaved = false
                    let payment_hash = payment["payment_hash"] as? String ?? ""
                    let amount = Int(payment["value_sat"] as? String ?? "")!.withCommas
                    let status = payment["status"] as? String ?? ""
                    let created = Double(payment["creation_time_ns"] as? String ?? "0.0")! / 1000000000.0
                    let invoice = payment["payment_request"] as? String ?? ""
                    let date = Date(timeIntervalSince1970: created)
                    dateFormatter.dateFormat = "MMM-dd-yyyy HH:mm"
                    let dateString = dateFormatter.string(from: date)
                    
                    if status == "SUCCEEDED" {
                        
                        let amountBtc = amount.satsToBtc.btcBalanceWithSpaces
                        let fxRate = UserDefaults.standard.object(forKey: "fxRate") as? Double ?? 0.0
                        let amountFiat = (amountBtc.doubleValue * fxRate).balanceText
                        
                        arrayToReturn.append([
                                                "address": invoice,
                                                "amountSats": "-\(amount)",
                                                "amountBtc": amountBtc,
                                                "amountFiat": amountFiat,
                                                "confirmations": "Sent",
                                                "label": "",
                                                "date": dateString,
                                                "rbf": false,
                                                "txID": payment_hash,
                                                "replacedBy": "",
                                                "selfTransfer":false,
                                                "remove":false,
                                                "onchain":false,
                                                "isLightning":true,
                                                "sortDate":date])
                        
                        guard let savedTxs = savedTxs else {
                            saveLocally(txid: payment_hash, date: date)
                            
                            if p + 1 == payments.count {
                                arrayToReturn = arrayToReturn.sorted{ ($0["sortDate"] as? Date ?? Date()) > ($1["sortDate"] as? Date ?? Date()) }
                                completion((arrayToReturn, nil))
                            }
                            
                            return
                        }
                        
                        for (s, savedTx) in savedTxs.enumerated() {
                            let savedTxStruct = TransactionStruct(dictionary: savedTx)
                            
                            if savedTxStruct.txid == payment_hash {
                                alreadySaved = true
                            }
                            
                            if s + 1 == savedTxs.count {
                                if !alreadySaved {
                                    saveLocally(txid: payment_hash, date: date)
                                }
                            }
                        }
                    }
                    
                    if p + 1 == payments.count {
                        arrayToReturn = arrayToReturn.sorted{ ($0["sortDate"] as? Date ?? Date()) > ($1["sortDate"] as? Date ?? Date()) }
                        completion((arrayToReturn, nil))
                    }
                }
            }
        }
    }
    
    // MARK: Section 1 parsers
    
    class func parseMiningInfo(miningInfo: [String:Any], completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        var miningInfoToReturn = [String:Any]()
        let hashesPerSecond = miningInfo["networkhashps"] as? Double ?? 0.0
        let exahashesPerSecond = hashesPerSecond / 1000000000000000000
        miningInfoToReturn["networkhashps"] = Int(exahashesPerSecond).withCommas
        miningInfoToReturn["rawData"] = miningInfo
        completion((miningInfoToReturn, nil))
    }
    
    class func parsePeerInfo(peerInfo: NSArray, completion: @escaping ((response: GetPeerInfoResponse?, errorMessage: String?)) -> Void) {
       guard let getPeerInfoResponse = try? GetPeerInfoResponse(from: peerInfo) else {
           completion((nil, "Error parsing peer info, please let us know about this."))
            return
        }
    
        completion((getPeerInfoResponse, nil))
    }
    
    class func parseNetworkInfo(networkInfo: [String:Any], completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        var networkInfoToReturn = [String:Any]()
        let subversion = (networkInfo["subversion"] as! String).replacingOccurrences(of: "/", with: "")
        let version = subversion.replacingOccurrences(of: "Satoshi:", with: "")
        networkInfoToReturn["subversion"] = version
        let versionInt = networkInfo["version"] as! Int
        UserDefaults.standard.set(versionInt, forKey: "version")
        
        let networks = networkInfo["networks"] as! NSArray
        
        for network in networks {
            let dict = network as! [String:Any]
            let name = dict["name"] as! String
            
            if name == "onion" {
                let reachable = dict["reachable"] as! Bool
                networkInfoToReturn["reachable"] = reachable
            }
        }
        
        networkInfoToReturn["rawData"] = networkInfo
        
        completion((networkInfoToReturn, nil))
    }
    
    class func parseTransactions(transactions: NSArray) {
        arrayToReturn.removeAll()
                
        for item in transactions {
            if let transaction = item as? [String:Any] {
                var label = String()
                var replaced_by_txid = String()
                let address = transaction["address"] as? String ?? ""
                let amount = transaction["amount"] as? Double ?? 0.0
                let amountString = amount.avoidNotation
                let confirmations = transaction["confirmations"] as! Int
                
                if let replaced_by_txid_check = transaction["replaced_by_txid"] as? String {
                    replaced_by_txid = replaced_by_txid_check
                }
                
                if let labelCheck = transaction["label"] as? String {
                    label = labelCheck
                    if labelCheck == "" || labelCheck == "," {
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
                
                let amountSats = amountString.btcToSats
                let amountBtc = amountString.doubleValue.btcBalanceWithSpaces
                let fxRate = UserDefaults.standard.object(forKey: "fxRate") as? Double ?? 0.0
                let amountFiat = (amountString.doubleValue * fxRate).balanceText
                
                let tx = [
                    "address": address,
                    "amountBtc": amountBtc,
                    "amountSats": amountSats,
                    "amountFiat": amountFiat,
                    "confirmations": confirmations,
                    "label": label,
                    "date": dateString,
                    "rbf": rbf,
                    "txID": txID,
                    "replacedBy": replaced_by_txid,
                    "selfTransfer": false,
                    "remove": false,
                    "onchain": true,
                    "isLightning": false,
                    "sortDate": date
                ] as [String:Any]
                
                arrayToReturn.append(tx)
                                
                func saveLocally() {
                    #if DEBUG
                    print("saveLocally")
                    #endif
                    var labelToSave = "no transaction label"
                    
                    if label != "" {
                        labelToSave = label
                    }
                    
                    let dict = [
                        "txid":txID,
                        "id":UUID(),
                        "memo":"no transaction memo",
                        "date":date,
                        "label":labelToSave
                    ] as [String:Any]
                    
                    CoreDataService.saveEntity(dict: dict, entityName: .transactions) { _ in }
                }
                
                CoreDataService.retrieveEntity(entityName: .transactions) { txs in
                    guard let txs = txs, txs.count > 0 else {
                        saveLocally()
                        return
                    }
                    
                    var alreadySaved = false
                    
                    for (i, tx) in txs.enumerated() {
                        let txStruct = TransactionStruct(dictionary: tx)
                        if txStruct.txid == txID {
                            alreadySaved = true
                        }
                        if i + 1 == txs.count {
                            if !alreadySaved {
                                saveLocally()
                            }
                        }
                    }
                }
            }
        }
    }
}
