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
            listUnspent(completion: completion)
        } else {
            dictToReturn["unconfirmedBalance"] = "disabled"
            dictToReturn["onchainBalance"] = "disabled"
            completion((dictToReturn, nil))
        }
    }
    
    class func listUnspent(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        Reducer.makeCommand(command: .listunspent, param: "0") { (response, errorMessage) in
            if let utxos = response as? NSArray {
                parseUtxos(utxos: utxos)
                getLightningBalances(completion: completion)
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
    
    class func getLightningBalances(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        CoreDataService.retrieveEntity(entityName: .newNodes) { nodes in
            guard let nodes = nodes else { return }
            
            for node in nodes {
                let nodeStr = NodeStruct(dictionary: node)
                
                if nodeStr.isLightning {
                    if nodeStr.macaroon == nil {
                        getOffChainBalanceCL(completion: completion)
                        break
                    } else {
                        getOffChainBalanceLND(completion: completion)
                        break
                    }
                }
            }
        }
    }
    
    class func getOffChainBalanceLND(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        let lnd = LndRpc.sharedInstance
        lnd.makeLndCommand(command: .channelbalance) { (response, error) in
            guard let dict = response,
                  let localBalance = dict["local_balance"] as? NSDictionary else {
                dictToReturn["offchainBalance"] = "0.00000000"
                completion((dictToReturn, error ?? ""))
                return
            }
            
            let localBalanceSats = localBalance["sat"] as! String
            
            lnd.makeLndCommand(command: .walletbalance) { (response, error) in
                guard let dict = response,
                      let walletBalance = dict["total_balance"] as? String else {
                    dictToReturn["offchainBalance"] = localBalanceSats
                    completion((dictToReturn, error ?? ""))
                    return
                }
                
                let total = Int(localBalanceSats)! + Int(walletBalance)!
                dictToReturn["offchainBalance"] = "\(total)"
                completion((dictToReturn, error ?? ""))
            }
        }
    }
    
    class func getOffChainBalanceCL(completion: @escaping ((response: [String:Any]?, errorMessage: String?)) -> Void) {
        let id = UUID()
        LightningRPC.command(id: id, method: .listfunds, param: "") { (uuid, responseDict, errorDesc) in
            guard uuid == id, let dict = responseDict as? NSDictionary, let outputs = dict["outputs"] as? NSArray, outputs.count > 0 else {
                dictToReturn["offchainBalance"] = "0.00000000"
                completion((dictToReturn, errorDesc ?? ""))
                return
            }
            
            var offchainBalance = 0.0
            
            for (i, output) in outputs.enumerated() {
                
                if let outputDict = output as? NSDictionary {
                    
                    if let sats = outputDict["value"] as? Int {
                        let btc = Double(sats) / 100000000.0
                        offchainBalance += btc
                        dictToReturn["offchainBalance"] = "\(rounded(number: offchainBalance).avoidNotation)"
                    }
                    
                    if let txid = outputDict["txid"] as? String {
                        offchainTxids.append(txid)
                    }
                }
                
                if i + 1 == outputs.count {
                    guard let channels = dict["channels"] as? NSArray, channels.count > 0 else {
                        completion((dictToReturn, nil))
                        return
                    }
                    
                    for (c, channel) in channels.enumerated() {
                        
                        if let channelDict = channel as? NSDictionary {
                            
                            if let funding_txid = channelDict["funding_txid"] as? String {
                                offchainTxids.append(funding_txid)
                            }
                            
                            if let our_amount_msat = channelDict["our_amount_msat"] as? String {
                                
                                if let our_msats = Int(our_amount_msat.replacingOccurrences(of: "msat", with: "")) {
                                    let btc = Double(our_msats) / 100000000000.0
                                    offchainBalance += btc
                                }
                            }
                        }
                        
                        if c + 1 == channels.count {
                            dictToReturn["offchainBalance"] = "\(rounded(number: offchainBalance).avoidNotation)"
                            completion((dictToReturn, nil))
                        }
                    }
                }
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
            Reducer.makeCommand(command: .listtransactions, param: "\"*\", 1000, 0, true") { (response, errorMessage) in
                if let transactions = response as? NSArray {
                    parseTransactions(transactions: transactions)
                    getOffchainTransactions(completion: completion)
                }
            }
        } else {
            arrayToReturn = []
            completion((arrayToReturn, nil))
        }
    }
    
    class func getOffchainTransactions(completion: @escaping ((response: [[String:Any]]?, errorMessage: String?)) -> Void) {
        
        func getPaid() {
            let id = UUID()
            LightningRPC.command(id: id, method: .listinvoices, param: "") { (uuid, response, errorDesc) in
                guard id == uuid, let dict = response as? NSDictionary, let payments = dict["invoices"] as? NSArray, payments.count > 0 else {
                    arrayToReturn = arrayToReturn.sorted{ ($0["sortDate"] as? Date ?? Date()) > ($1["sortDate"] as? Date ?? Date()) }
                    completion((arrayToReturn, nil))
                    return
                }
                
                for (i, payment) in payments.enumerated() {
                    if let paymentDict = payment as? NSDictionary {
                        let payment_hash = paymentDict["payment_hash"] as? String ?? ""
                        var amountMsat = paymentDict["msatoshi"] as? Int ?? 0
                        if amountMsat == 0 {
                            amountMsat = paymentDict["msatoshi_received"] as? Int ?? 0
                        }
                        let status = paymentDict["status"] as? String ?? ""
                        let bolt11 = paymentDict["bolt11"] as? String ?? ""
                        let label = paymentDict["label"] as? String ?? ""
                        let paid_at = paymentDict["paid_at"] as? Int ?? 0
                        
                        let date = Date(timeIntervalSince1970: Double(paid_at))
                        dateFormatter.dateFormat = "MMM-dd-yyyy HH:mm"
                        let dateString = dateFormatter.string(from: date)
                        
                        if status == "paid" {
                            arrayToReturn.append([
                                "address": bolt11,
                                "amount": "\(Double(amountMsat) / 1000.0) sats",
                                "confirmations": status,
                                "label": label,
                                "date": dateString,
                                "rbf": false,
                                "txID": payment_hash,
                                "replacedBy": "",
                                "selfTransfer":false,
                                "remove":false,
                                "onchain":false,
                                "isLightning":true,
                                "sortDate":date])
                        }
                                                            
                        if i + 1 == payments.count {
                            arrayToReturn = arrayToReturn.sorted{ ($0["sortDate"] as? Date ?? Date()) > ($1["sortDate"] as? Date ?? Date()) }
                            completion((arrayToReturn, nil))
                        }
                    }
                }
            }
        }
        
        func getSent() {
            let id = UUID()
            LightningRPC.command(id: id, method: .listsendpays, param: "") { (uuid, response, errorDesc) in
                guard uuid == id, let dict = response as? NSDictionary, let payments = dict["payments"] as? NSArray, payments.count > 0 else {
                    getPaid()
                    return
                }
                
                for (i, payment) in payments.enumerated() {
                    if let paymentDict = payment as? NSDictionary {
                        let payment_hash = paymentDict["payment_hash"] as? String ?? ""
                        let amountMsat = paymentDict["msatoshi_sent"] as? Int ?? 0
                        let status = paymentDict["status"] as? String ?? ""
                        let created = paymentDict["created_at"] as? Int ?? 0
                        let bolt11 = paymentDict["bolt11"] as? String ?? ""
                        let date = Date(timeIntervalSince1970: Double(created))
                        dateFormatter.dateFormat = "MMM-dd-yyyy HH:mm"
                        let dateString = dateFormatter.string(from: date)
                        
                        if status != "failed" {
                            arrayToReturn.append([
                                "address": bolt11,
                                "amount": "-\(Double(amountMsat) / 1000.0) sats",
                                "confirmations": status,
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
                        }
                        
                        if i + 1 == payments.count {
                            getPaid()
                        }
                    }
                }
            }
        }
        
        let id = UUID()
        LightningRPC.command(id: id, method: .listtransactions, param: "") { (uuid, responseDict, errorDesc) in
            guard uuid == id, let dict = responseDict as? NSDictionary, let transactions = dict["transactions"] as? NSArray, transactions.count > 0 else {
                getSent()
                return
            }
            
            for (t, transaction) in transactions.enumerated() {
                guard let txDict = transaction as? NSDictionary, let hash = txDict["hash"] as? String, arrayToReturn.count > 0 else {
                    getSent()
                    return
                }
                
                for (o, onchainTx) in arrayToReturn.enumerated() {
                    if onchainTx["txID"] as! String == hash {
                        arrayToReturn[o]["isLightning"] = true
                    }
                    
                    if t + 1 == transactions.count && o + 1 == arrayToReturn.count {
                        getSent()
                    }
                }
            }
        }
    }
    
    private class func saveUtxoLocally(_ utxo: UtxosStruct) {
        activeWallet { wallet in
            // Only save utxos for Fully Noded wallets
            guard let wallet = wallet else { return }
            
            CoreDataService.retrieveEntity(entityName: .utxos) { savedUtxos in
                if let savedUtxos = savedUtxos, savedUtxos.count > 0 {
                    var alreadySaved = false
                    var updateLabel = false
                    
                    for (i, savedUtxo) in savedUtxos.enumerated() {
                        let savedUtxoStr = UtxosStruct(dictionary: savedUtxo)
                        
                        if savedUtxoStr.txid == utxo.txid && savedUtxoStr.vout == utxo.vout {
                            alreadySaved = true
                            
                            if savedUtxoStr.label == "" && utxo.label != "" {
                                updateLabel = true
                            }
                        }

                        if i + 1 == savedUtxos.count {
                            if !alreadySaved {
                                saveUtxo(utxo, wallet)
                            } else if updateLabel {
                                updateUtxoLabel(id: savedUtxoStr.id!, newLabel: savedUtxoStr.label ?? "")
                            }
                        }
                    }
                } else {
                    saveUtxo(utxo, wallet)
                }
            }
        }
    }
    
    class private func updateUtxoLabel(id: UUID, newLabel: String) {
        CoreDataService.update(id: id, keyToUpdate: "label", newValue: newLabel, entity: .utxos) { success in
            #if DEBUG
            print("updated utxo locally: \(success)\nlabel: \(newLabel)")
            #endif
        }
    }
    
    class private func saveUtxo(_ utxo: UtxosStruct, _ wallet: Wallet) {
        var dict = [String:Any]()
        dict["txid"] = utxo.txid
        dict["vout"] = utxo.vout
        dict["label"] = utxo.label
        dict["id"] = UUID()
        dict["walletId"] = wallet.id
        dict["address"] = utxo.address
        dict["amount"] = utxo.amount
        dict["desc"] = utxo.desc
        dict["solvable"] = utxo.solvable
        dict["confirmations"] = utxo.confs
        dict["safe"] = utxo.safe
        dict["spendable"] = utxo.spendable
        
        CoreDataService.saveEntity(dict: dict, entityName: .utxos) { success in
            #if DEBUG
            print("saved utxo locally: \(success)\nlabel: \(utxo.label ?? "")")
            #endif
        }
    }
    
    class func parseUtxos(utxos: NSArray) {
        var amount = 0.0
        var indexArray = [Int]()
        
        for (x, utxo) in utxos.enumerated() {
            let utxoDict = utxo as! NSDictionary
            let utxoStr = UtxosStruct(dictionary: utxo as! [String:Any])
            saveUtxoLocally(utxoStr)
            
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
            dictToReturn["onchainBalance"] = "\((round(100000000*amount)/100000000).avoidNotation)"
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
        let version = subversion.replacingOccurrences(of: "Satoshi:", with: "")
        networkInfoToReturn["subversion"] = version
        UserDefaults.standard.set(version, forKey: "version")
        
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
        var activeWalletId:UUID?
        
        arrayToReturn.removeAll()
        
        activeWallet { activeWallet in
            if activeWallet != nil {
                activeWalletId = activeWallet!.id
            }
            
            var transactionArray = [[String:Any]]()
            
            for (t, item) in transactions.enumerated() {
                
                if let transaction = item as? NSDictionary {
                    var toRemove = false
                    var label = String()
                    var replaced_by_txid = String()
                    
                    let address = transaction["address"] as? String ?? ""
                    let amount = transaction["amount"] as? Double ?? 0.0
                    let amountString = amount.avoidNotation
                    let confsCheck = transaction["confirmations"] as? Int ?? 0
                    
                    if confsCheck < 0 {
                        toRemove = true
                    }
                    
                    let confirmations = String(confsCheck)
                    
                    if let replaced_by_txid_check = transaction["replaced_by_txid"] as? String {
                        replaced_by_txid = replaced_by_txid_check
                        
                        if replaced_by_txid != "" {
                            toRemove = true
                        }
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
                    
                    func finishParsingTxs() {
                        if t + 1 == transactions.count {
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
                                                    
                            for tx in transactionArray {
                                if let remove = tx["remove"] as? Bool {
                                    if !remove {
                                        arrayToReturn.append(tx)
                                    }
                                }
                            }
                        }
                    }
                                    
                    transactionArray.append([
                        "address": address,
                        "amount": amountString,
                        "confirmations": confirmations,
                        "label": label,
                        "date": dateString,
                        "rbf": rbf,
                        "txID": txID,
                        "replacedBy": replaced_by_txid,
                        "selfTransfer":false,
                        "remove":toRemove,
                        "onchain":true,
                        "isLightning":false,
                        "sortDate":date
                    ])
                    
                    func saveLocally() {
                        let dict = [
                            "txid":txID,
                            "id":UUID(),
                            "walletId":activeWalletId!,
                            "memo":"no transaction memo",
                            "date":date,
                            "label":"no transaction label"
                        ] as [String:Any]
                        
                        CoreDataService.saveEntity(dict: dict, entityName: .transactions) { _ in }
                    }
                    
                    CoreDataService.retrieveEntity(entityName: .transactions) { txs in
                        guard let txs = txs, txs.count > 0 else {
                            if activeWalletId != nil {
                                saveLocally()
                            }
                            finishParsingTxs()
                            return
                        }
                        
                        var alreadySaved = false
                        
                        for (i, tx) in txs.enumerated() {
                            let txStruct = TransactionStruct(dictionary: tx)
                            if txStruct.txid == txID {
                                alreadySaved = true
                            }
                            if i + 1 == txs.count {
                                if !alreadySaved && activeWalletId != nil {
                                    saveLocally()
                                }
                                
                                if t + 1 == transactions.count {
                                    finishParsingTxs()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
