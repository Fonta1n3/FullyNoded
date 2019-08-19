//
//  MainMenuViewController.swift
//  BitSense
//
//  Created by Peter on 08/09/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit
import KeychainSwift

class MainMenuViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITabBarControllerDelegate {
    
    @IBOutlet var activeWallet: UILabel!
    let dateFormatter = DateFormatter()
    var syncStatus = ""
    var hashrateString = String()
    var version = String()
    var incomingCount = Int()
    var outgoingCount = Int()
    var isPruned = Bool()
    var tx = String()
    var currentBlock = Int()
    var newFee = Double()
    var latestBlockHeight = Int()
    var balance = Double()
    var transactionArray = [[String: Any]]()
    @IBOutlet var mainMenu: UITableView!
    var refresher: UIRefreshControl!
    
    var ssh:SSHService!
    var makeSSHCall:SSHelper!
    var torClient:TorClient!
    var torRPC:MakeRPCCall!
    var isUsingSSH = Bool()
    var torConnected = Bool()
    
    var connectingView = ConnectingView()
    let plusImage = UIImageView()
    let minusImage = UIImageView()
    let cd = CoreDataService()
    var nodes = [[String:Any]]()
    var uptime = Int()
    var activeNode = [String:Any]()
    var existingNodeID = ""
    var initialLoad = Bool()
    var exisitingWallet = ""
    var mempoolCount = Int()
    var walletDisabled = Bool()
    var torReachable = Bool()
    var progress = ""
    var difficulty = ""
    var size = ""
    var hotBalance = ""
    var coldBalance = ""
    var unconfirmedBalance = ""
    var network = ""
    var nodeLabel = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("main menu")
        
        initialLoad = true
        let keychain = KeychainSwift()
        
        if UserDefaults.standard.object(forKey: "updatedToSwift5") == nil {
            
            keychain.delete("UnlockPassword")
            keychain.delete("AESPassword")
            deleteAllNodes()
            UserDefaults.standard.removeObject(forKey: "firstTime")
            
        }
        
        firstTimeHere()
        mainMenu.delegate = self
        tabBarController!.delegate = self
        configureRefresher()
        mainMenu.tableFooterView = UIView(frame: .zero)
        
        //torConnected = false
        //connectWithTor()
        
        if keychain.get("UnlockPassword") != nil {
            
            DispatchQueue.main.async {
                
                self.performSegue(withIdentifier: "lockScreen", sender: self)
                
            }
            
        }
        
        if UserDefaults.standard.object(forKey: "feeTarget") == nil {
         
            UserDefaults.standard.set(1008, forKey: "feeTarget")
            
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        //if torConnected {
        
        let ud = UserDefaults.standard
        var walletName = ""
        
        if ud.object(forKey: "walletName") != nil {
            
            walletName = ud.object(forKey: "walletName") as! String
            
        }
        
        nodes = cd.retrieveCredentials()
        
        if nodes.count > 0 {
            
            let isActive = isAnyNodeActive(nodes: nodes)
            
            if isActive {
                
                for node in nodes {
                    
                    if (node["isActive"] as! Bool) {
                        
                        self.activeNode = node
                        let newId = node["id"] as! String
                        
                        if newId != existingNodeID {
                            
                            if !initialLoad {
                                
                                ud.removeObject(forKey: "walletName")
                                
                            }
                            
                            IsUsingSSH.sharedInstance = node["usingSSH"] as! Bool
                            self.isUsingSSH = IsUsingSSH.sharedInstance
                            self.refresh()
                            
                        } else if walletName != self.exisitingWallet && walletName != "" {
                            
                            IsUsingSSH.sharedInstance = node["usingSSH"] as! Bool
                            self.isUsingSSH = IsUsingSSH.sharedInstance
                            self.refresh()
                            
                        }
                        
                    }
                    
                }
                
            } else {
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "No active nodes")
                
            }
            
        } else {
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "Go to Nodes to add your own node")
            
        }
        
        initialLoad = false
            
        //}
        
    }
    
    
    
    func loadTableDataTor(method: BTC_CLI_COMMAND, param: Any) {
        print("loadTableDataTor")
        
        func getResult() {
            print("get result")
            
            if !torRPC.errorBool {
                
                DispatchQueue.main.async {
                    
                    self.connectingView.label.text = "bitcoin-cli \(method.rawValue)"
                    
                }
                
                switch method {
                    
                case BTC_CLI_COMMAND.getmempoolinfo:
                    
                    let dict = torRPC.dictToReturn
                    self.mempoolCount = dict["size"] as! Int
                    
                    DispatchQueue.main.async {
                        
                        self.removeSpinner()
                        self.mainMenu.reloadData()
                        
                    }
                    
                case BTC_CLI_COMMAND.listunspent:
                    
                    let utxos = torRPC.arrayToReturn
                    parseUtxos(utxos: utxos)
                    
                case BTC_CLI_COMMAND.uptime:
                    
                    self.uptime = Int(torRPC.doubleToReturn)
                    
                    self.loadTableDataTor(method: BTC_CLI_COMMAND.listunspent,
                                          param: "0")
                    
                case BTC_CLI_COMMAND.getmininginfo:
                    
                    let miningInfo = torRPC.dictToReturn
                    parseMiningInfo(miningInfo: miningInfo)
                    
                case BTC_CLI_COMMAND.getnetworkinfo:
                    
                    let networkInfo = torRPC.dictToReturn
                    parseNetworkInfo(networkInfo: networkInfo)
                    
                case BTC_CLI_COMMAND.getpeerinfo:
                    
                    let peerInfo = torRPC.arrayToReturn
                    parsePeerInfo(peerInfo: peerInfo)
                    
                case BTC_CLI_COMMAND.abandontransaction:
                    
                    displayAlert(viewController: self,
                                 isError: false,
                                 message: "Transaction abandoned")
                    
                case BTC_CLI_COMMAND.getblockchaininfo:
                    
                    let blockchainInfo = torRPC.dictToReturn
                    parseBlockchainInfo(blockchainInfo: blockchainInfo)
                    
                case BTC_CLI_COMMAND.bumpfee:
                    
                    let result = torRPC.dictToReturn
                    bumpFee(result: result)
                    
                case BTC_CLI_COMMAND.getunconfirmedbalance:
                    
                    let unconfirmedBalance = torRPC.doubleToReturn
                    parseUncomfirmedBalance(unconfirmedBalance: unconfirmedBalance)
                    
                case BTC_CLI_COMMAND.getbalance:
                    
                    let balanceCheck = torRPC.doubleToReturn
                    parseBalance(balance: balanceCheck)
                    
                case BTC_CLI_COMMAND.listtransactions:
                    
                    let transactionsCheck = torRPC.arrayToReturn
                    parseTransactions(transactions: transactionsCheck)
                    
                default:
                    
                    break
                    
                }
                
            } else {
                
                if isWalletRPC(command: method) {
                    
                    //its a wallet command skip incase wallet is disabled
                    print("error with wallet command")
                    
                    //walletDisabled = true
                    
                    self.removeSpinner()
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: torRPC.errorDescription + " " + ". Last command: \(method.rawValue)")
                    
                    switch method {
                        
                    case BTC_CLI_COMMAND.listtransactions:
                        
                        parseTransactions(transactions: [])
                        
                    case BTC_CLI_COMMAND.getbalance:
                        
                        parseBalance(balance: 0.0)
                        
                    case BTC_CLI_COMMAND.getunconfirmedbalance:
                        
                        parseUncomfirmedBalance(unconfirmedBalance: 0.0)
                        
                    case BTC_CLI_COMMAND.listunspent:
                        
                        parseUtxos(utxos: [])
                        
                    default:
                        
                        break
                        
                    }
                    
                } else {
                    
                    self.removeSpinner()
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: torRPC.errorDescription + " " + ". Last command: \(method.rawValue)")
                    
                }
                
            }
            
        }
        
        if self.torClient.isOperational {
        
            self.torRPC.executeRPCCommand(method: method,
                                          param: param,
                                          completion: getResult)
            
        } else {
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "Tor not connected")
            
        }
        
    }
    
    /*func connectWithTor() {
        
//        self.connectingView.addConnectingView(vc: self,
//                                              description: "Connecting Tor")
//
//        Tor only working well on simulator or when device is connected to Xcode - PLEASE HELP
//
//        torClient = TorClient.sharedInstance
//        
//        func getData() {
//            print("getData")
//
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                
//                self.torConnected = true
                
                self.nodes = self.cd.retrieveCredentials()
                
                if self.nodes.count > 0 {
                    
                    let ud = UserDefaults.standard
                    
                    let isActive = self.isAnyNodeActive(nodes: self.nodes)
                    
                    if isActive {
                        
                        for node in self.nodes {
                            
                            if (node["isActive"] as! Bool) {
                                
                                self.activeNode = node
                                
                                let newId = node["id"] as! String
                                
                                if newId != self.existingNodeID {
                                    
                                    if !self.initialLoad {
                                        
                                        ud.removeObject(forKey: "walletName")
                                        
                                    }
                                    
                                    self.isUsingSSH = node["usingSSH"] as! Bool
                                    self.refresh()
                                    
                                }
                                
                            }
                            
                        }
                        
                    } else {
                        
                        displayAlert(viewController: self,
                                     isError: true,
                                     message: "No active nodes")
                        
                    }
                    
                    if ud.object(forKey: "walletName") != nil {
                        
                        DispatchQueue.main.async {
                            
                            self.activeWallet.text = (ud.object(forKey: "walletName") as! String)
                            
                        }
                        
                    } else {
                        
                        DispatchQueue.main.async {
                            
                            self.activeWallet.text = ""
                            
                        }
                        
                    }
                    
                } else {
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: "Go to Nodes to add a node")
                    
                }
                
                self.initialLoad = false
                
            //}
            
        //}
        
        //torClient.start(completion: getData)
        
    }*/
    
    //MARK: Tableview Methods
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        return 3
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        switch section {
            
        case 0:
            
            return 1
            
        case 1:
            
            return 1
            
        case 2:
            
            if transactionArray.count > 0 {
                
                return transactionArray.count
                
            } else {
                
                return 1
                
            }
            
            
        default:
            
            return 0
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        switch indexPath.section {
            
        case 0:
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            let hotBalanceLabel = cell.viewWithTag(1) as! UILabel
            let coldBalanceLabel = cell.viewWithTag(2) as! UILabel
            let unconfirmedLabel = cell.viewWithTag(3) as! UILabel
            hotBalanceLabel.text = self.hotBalance
            coldBalanceLabel.text = self.coldBalance
            unconfirmedLabel.text = self.unconfirmedBalance
            return cell
            
        case 1:
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "NodeInfo", for: indexPath)
            cell.selectionStyle = .none
            cell.isSelected = false
            let network = cell.viewWithTag(1) as! UILabel
            let pruned = cell.viewWithTag(2) as! UILabel
            let connections = cell.viewWithTag(3) as! UILabel
            let version = cell.viewWithTag(4) as! UILabel
            let hashRate = cell.viewWithTag(5) as! UILabel
            let sync = cell.viewWithTag(6) as! UILabel
            let blockHeight = cell.viewWithTag(7) as! UILabel
            let uptime = cell.viewWithTag(8) as! UILabel
            let wallet = cell.viewWithTag(9) as! UILabel
            let mempool = cell.viewWithTag(10) as! UILabel
            let tor = cell.viewWithTag(11) as! UILabel
            let difficultyLabel = cell.viewWithTag(12) as! UILabel
            let sizeLabel = cell.viewWithTag(13) as! UILabel
            let nodeLabel = cell.viewWithTag(14) as! UILabel
            
            if self.hashrateString != "" {
                
                nodeLabel.text = self.nodeLabel
                sizeLabel.text = self.size
                difficultyLabel.text = self.difficulty
                sync.text = self.progress
                
                if torReachable {
                    
                    tor.text = "Reachable"
                    
                } else {
                    
                    tor.text = "Not reachable"
                    
                }
                
                mempool.text = "\(self.mempoolCount)"
                
                if UserDefaults.standard.object(forKey: "walletName") != nil {
                    
                    wallet.text = (UserDefaults.standard.object(forKey: "walletName") as! String)
                    
                } else {
                    
                    wallet.text = "Default"
                    
                }
                
                if self.isPruned {
                    
                    pruned.text = "True"
                    
                } else if !self.isPruned {
                    
                    pruned.text = "False"
                }
                
                if self.network != "" {
                    
                    network.text = self.network
                    
                }
                
                blockHeight.text = "\(self.currentBlock.withCommas())"
                connections.text = "\(outgoingCount) outgoing / \(incomingCount) incoming"
                version.text = self.version
                hashRate.text = self.hashrateString + " " + "h/s"
                uptime.text = "\(self.uptime / 86400) days \((self.uptime % 86400) / 3600) hours"
                
            }
            
            return cell
            
        case 2:
            
            if transactionArray.count == 0 {
                
                let cell = UITableViewCell()
                cell.alpha = 0
                cell.backgroundColor = view.backgroundColor
                return cell
                
            } else {
                
                let cell = tableView.dequeueReusableCell(withIdentifier: "MainMenuCell",
                                                         for: indexPath)
                
                cell.selectionStyle = .none
                
                let addressLabel = cell.viewWithTag(1) as! UILabel
                let amountLabel = cell.viewWithTag(2) as! UILabel
                let confirmationsLabel = cell.viewWithTag(3) as! UILabel
                let labelLabel = cell.viewWithTag(4) as! UILabel
                let dateLabel = cell.viewWithTag(5) as! UILabel
                let watchOnlyLabel = cell.viewWithTag(6) as! UILabel
                
                mainMenu.separatorColor = UIColor.white
                let dict = self.transactionArray[indexPath.row]
                
                addressLabel.text = dict["address"] as? String
                
                let amount = dict["amount"] as! String
                
                if amount.hasPrefix("-") {
                    
                    amountLabel.text = amount
                    amountLabel.textColor = UIColor.darkGray
                    
                } else {
                    
                    amountLabel.text = "+" + amount
                    amountLabel.textColor = UIColor.white
                    
                }
                
                confirmationsLabel.text = (dict["confirmations"] as! String) + " " + "Confs"
                let label = dict["label"] as? String
                
                if label != "," {
                    
                    labelLabel.text = label
                    
                } else if label == "," {
                    
                    labelLabel.text = ""
                    
                }
                
                dateLabel.text = dict["date"] as? String
                
                if dict["abandoned"] as? Bool == true {
                    
                    cell.backgroundColor = UIColor.red
                    
                }
                
                if dict["involvesWatchonly"] as? Bool == true {
                    
                    watchOnlyLabel.text = "COLD"
                    
                } else {
                    
                    watchOnlyLabel.text = ""
                    
                }
                
                return cell
                
            }
            
        default:
            
            let cell = UITableViewCell()
            cell.selectionStyle = .none
            cell.backgroundColor = view.backgroundColor
            cell.alpha = 0
            return cell
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        if section == 0 {
            
            return "Balances"
            
        } else if section == 1 {
            
            return "Node stats"
            
        } else {
            
            return "Last 50 transactions"
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        
        (view as! UITableViewHeaderFooterView).backgroundView?.backgroundColor = UIColor.clear
        (view as! UITableViewHeaderFooterView).textLabel?.textAlignment = .right
        (view as! UITableViewHeaderFooterView).textLabel?.font = UIFont.init(name: "HiraginoSans-W3", size: 15)
        (view as! UITableViewHeaderFooterView).textLabel?.textColor = UIColor.green
        (view as! UITableViewHeaderFooterView).textLabel?.alpha = 1
        
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        if section == 0 {
            
            return 30
            
        } else {
            
            return 20
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        if indexPath.section == 0 {
            
            return 142
            
        } else if indexPath.section == 1{
            
            return 269
            
        } else {
            
            return 101
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if transactionArray.count > 0 {
         
            if indexPath.section == 2 {
                
                let cell = tableView.cellForRow(at: indexPath)!
                
                DispatchQueue.main.async {
                    
                    UIView.animate(withDuration: 0.2, animations: {
                        
                        cell.alpha = 0
                        
                    }) { _ in
                        
                        UIView.animate(withDuration: 0.2, animations: {
                            
                            cell.alpha = 1
                            
                        })
                        
                    }
                    
                }
                
                let selectedTx = self.transactionArray[indexPath.row]
                let txID = selectedTx["txID"] as! String
                self.tx = txID
                
                UIPasteboard.general.string = txID
                
                DispatchQueue.main.async {
                    
                    self.performSegue(withIdentifier: "getTransaction", sender: self)
                    
                }
                
            }
            
        }
        
    }
    
    //MARK: Result Parsers
    
    func parseMiningInfo(miningInfo: NSDictionary) {
        
        self.hashrateString = (miningInfo["networkhashps"] as! Double).withCommas()
        self.network = miningInfo["chain"] as! String
        
        loadTableDataSsh(method: BTC_CLI_COMMAND.uptime,
                         param: "")
        
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
        
        DispatchQueue.main.async {
            
            if amount == 0.0 {
                
                self.coldBalance = "0.00000000"
                
            } else {
                
                self.coldBalance = "\(round(100000000*amount)/100000000)"
                
            }
            
        }
        
        loadTableDataSsh(method: BTC_CLI_COMMAND.getmempoolinfo,
                         param: "")
        
    }
    
    func parseNetworkInfo(networkInfo: NSDictionary) {
        
        self.version = (networkInfo["subversion"] as! String).replacingOccurrences(of: "/", with: "")
        
        let networks = networkInfo["networks"] as! NSArray
        
        for network in networks {
            
            let dict = network as! NSDictionary
            let name = dict["name"] as! String
            
            if name == "onion" {
                
                let reachable = dict["reachable"] as! Bool
                torReachable = reachable
                
            }
            
        }
        
        self.loadTableDataSsh(method: BTC_CLI_COMMAND.getmininginfo,
                              param: "")
        
    }
    
    func parsePeerInfo(peerInfo: NSArray) {
        
        self.incomingCount = 0
        self.outgoingCount = 0
        
        for peer in peerInfo {
            
            let peerDict = peer as! NSDictionary
            
            let incoming = peerDict["inbound"] as! Bool
            
            if incoming {
                
                self.incomingCount = self.incomingCount + 1
                
            } else {
                
                self.outgoingCount = self.outgoingCount + 1
                
            }
            
        }
        
        self.loadTableDataSsh(method: BTC_CLI_COMMAND.getnetworkinfo,
                              param: "")
        
    }
    
    func parseBlockchainInfo(blockchainInfo: NSDictionary) {
        
        if let currentblockheight = blockchainInfo["blocks"] as? Int {
            
            self.currentBlock = currentblockheight
            
        }
        
        if let difficultyCheck = blockchainInfo["difficulty"] as? Double {
            
            difficulty = "\(difficultyCheck)"
            
        }
        
        if let sizeCheck = blockchainInfo["size_on_disk"] as? Int {
            
            size = "\(sizeCheck/1000000000) gigabytes"
            
        }
        
        if let progressCheck = blockchainInfo["verificationprogress"] as? Double {
            
            progress = "\(Int(progressCheck*100))%"
            
        }
        
        if let chain = blockchainInfo["chain"] as? String {
            
            self.network = chain
            
        }
        
        if let pruned = blockchainInfo["pruned"] as? Bool {
            
            if pruned {
                
                self.isPruned = true
                
            } else {
                
                self.isPruned = false
                
            }
            
        }
        
        self.loadTableDataSsh(method: BTC_CLI_COMMAND.listtransactions,
                              param: "\"*\", 50, 0, true")
        
    }
    
    func bumpFee(result: NSDictionary) {
        
        let originalFee = result["origfee"] as! Double
        let newFee = result["fee"] as! Double
        
        DispatchQueue.main.async {
            
            self.refresh()
            
        }
        
        displayAlert(viewController: self,
                     isError: false,
                     message: "Fee bumped from \(originalFee.avoidNotation) to \(newFee.avoidNotation)")
        
    }
    
    func parseUncomfirmedBalance(unconfirmedBalance: Double) {
        
        if unconfirmedBalance != 0.0 || unconfirmedBalance != 0 {
            
            DispatchQueue.main.async {
                
                self.unconfirmedBalance = "unconfirmed \(unconfirmedBalance.avoidNotation)"
                
                self.loadTableDataSsh(method: BTC_CLI_COMMAND.getpeerinfo,
                                      param: "")
                
            }
            
        } else {
            
            DispatchQueue.main.async {
                
                self.unconfirmedBalance = "unconfirmed 0.00000000"
                
                self.loadTableDataSsh(method: BTC_CLI_COMMAND.getpeerinfo,
                                      param: "")
                
            }
            
        }
        
    }
    
    func parseBalance(balance: Double) {
        
        self.balance = balance
        
        DispatchQueue.main.async {
            
            if self.balance == 0.0 {
                
                self.hotBalance = "0.00000000"
                
            } else {
                
                self.hotBalance = "\(round(100000000*balance)/100000000)"
                
            }
            
            self.loadTableDataSsh(method: BTC_CLI_COMMAND.getunconfirmedbalance,
                                  param: "")
            
        }
        
    }
    
    func parseTransactions(transactions: NSArray) {
        
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
                
                self.transactionArray.append(["address": address,
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
        
        DispatchQueue.main.async {
            
            self.transactionArray = self.transactionArray.reversed()
            self.mainMenu.reloadData()
            
        }
        
        self.loadTableDataSsh(method: BTC_CLI_COMMAND.getbalance,
                              param: "\"*\", 0, false")
        
    }
    
    //MARK: SSH Commands
    
    func loadTableDataSsh(method: BTC_CLI_COMMAND, param: String) {
        print("loadTableDataRpc")
        
        if !self.isUsingSSH {
            
            self.loadTableDataTor(method: method, param: param)
            
        } else {
            
            func getResult() {
                print("get result")
                
                if !makeSSHCall.errorBool {
                    
                    DispatchQueue.main.async {
                        
                        self.connectingView.label.text = "bitcoin-cli \(method.rawValue)"
                        
                    }
                    
                    switch method {
                        
                    case BTC_CLI_COMMAND.getmempoolinfo:
                        
                        let dict = makeSSHCall.dictToReturn
                        self.mempoolCount = dict["size"] as! Int
                        
                        DispatchQueue.main.async {
                            
                            self.removeSpinner()
                            self.mainMenu.reloadData()
                            
                        }
                        
                    case BTC_CLI_COMMAND.listunspent:
                        
                        let utxos = makeSSHCall.arrayToReturn
                        parseUtxos(utxos: utxos)
                        
                    case BTC_CLI_COMMAND.uptime:
                        
                        self.uptime = Int(makeSSHCall.doubleToReturn)
                        
                        self.loadTableDataSsh(method: BTC_CLI_COMMAND.listunspent,
                                              param: "0")
                        
                    case BTC_CLI_COMMAND.getmininginfo:
                        
                        let miningInfo = makeSSHCall.dictToReturn
                        parseMiningInfo(miningInfo: miningInfo)
                        
                    case BTC_CLI_COMMAND.getnetworkinfo:
                        
                        let networkInfo = makeSSHCall.dictToReturn
                        parseNetworkInfo(networkInfo: networkInfo)
                        
                    case BTC_CLI_COMMAND.getpeerinfo:
                        
                        let peerInfo = makeSSHCall.arrayToReturn
                        parsePeerInfo(peerInfo: peerInfo)
                        
                    case BTC_CLI_COMMAND.abandontransaction:
                        
                        displayAlert(viewController: self,
                                     isError: false,
                                     message: "Transaction abandoned")
                        
                    case BTC_CLI_COMMAND.getblockchaininfo:
                        
                        let blockchainInfo = makeSSHCall.dictToReturn
                        parseBlockchainInfo(blockchainInfo: blockchainInfo)
                        
                    case BTC_CLI_COMMAND.bumpfee:
                        
                        let result = makeSSHCall.dictToReturn
                        bumpFee(result: result)
                        
                    case BTC_CLI_COMMAND.getunconfirmedbalance:
                        
                        let unconfirmedBalance = makeSSHCall.doubleToReturn
                        parseUncomfirmedBalance(unconfirmedBalance: unconfirmedBalance)
                        
                    case BTC_CLI_COMMAND.getbalance:
                        
                        let balanceCheck = makeSSHCall.doubleToReturn
                        parseBalance(balance: balanceCheck)
                        
                    case BTC_CLI_COMMAND.listtransactions:
                        
                        let transactionsCheck = makeSSHCall.arrayToReturn
                        parseTransactions(transactions: transactionsCheck)
                        
                    default:
                        
                        break
                        
                    }
                    
                } else {
                    
                    if isWalletRPC(command: method) {
                        
                        //its a wallet command skip incase wallet is disabled
                        print("error with wallet command")
                        
                        //walletDisabled = true
                        
                        self.removeSpinner()
                        
                        displayAlert(viewController: self,
                                     isError: true,
                                     message: makeSSHCall.errorDescription + " " + ". Last command: \(method.rawValue)")
                        
                        switch method {
                            
                        case BTC_CLI_COMMAND.listtransactions:
                            
                            parseTransactions(transactions: [])
                            
                        case BTC_CLI_COMMAND.getbalance:
                            
                            parseBalance(balance: 0.0)
                            
                        case BTC_CLI_COMMAND.getunconfirmedbalance:
                            
                            parseUncomfirmedBalance(unconfirmedBalance: 0.0)
                            
                        case BTC_CLI_COMMAND.listunspent:
                            
                            parseUtxos(utxos: [])
                            
                        default:
                            
                            break
                            
                        }
                        
                    } else {
                        
                        self.removeSpinner()
                        
                        displayAlert(viewController: self,
                                     isError: true,
                                     message: makeSSHCall.errorDescription + " " + ". Last command: \(method.rawValue)")
                        
                    }
                    
                }
                
            }
            
            if self.ssh != nil {
                
                if self.ssh.session.isAuthorized {
                    
                    if self.ssh.session.isConnected {
                        
                        self.makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                                           method: method,
                                                           param: param,
                                                           completion: getResult)
                        
                    } else {
                        
                        displayAlert(viewController: self,
                                     isError: true,
                                     message: "SSH not connected")
                        
                    }
                    
                }
                
            } else {
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "SSH not connected")
                
            }
            
        }
        
    }
    
    func isWalletRPC(command: BTC_CLI_COMMAND) -> Bool {
        
        var boolToReturn = Bool()
        
        switch command {
            
        case BTC_CLI_COMMAND.listtransactions,
             BTC_CLI_COMMAND.getbalance,
             BTC_CLI_COMMAND.getunconfirmedbalance,
             BTC_CLI_COMMAND.getwalletinfo,
             BTC_CLI_COMMAND.importmulti,
             BTC_CLI_COMMAND.rescanblockchain,
             BTC_CLI_COMMAND.fundrawtransaction,
             BTC_CLI_COMMAND.listunspent,
             BTC_CLI_COMMAND.walletprocesspsbt,
             BTC_CLI_COMMAND.walletcreatefundedpsbt:
            
            boolToReturn = true
            
        default:
            
            boolToReturn = false
            
        }
        
        return boolToReturn
        
    }
    
    //MARK: User Interface
    
    func removeSpinner() {
        
        DispatchQueue.main.async {
            
            self.refresher.endRefreshing()
            self.connectingView.removeConnectingView()
            
        }
        
    }
    
    func configureRefresher() {
        
        refresher = UIRefreshControl()
        refresher.tintColor = UIColor.white
        
        refresher.attributedTitle = NSAttributedString(string: "pull to refresh",
                                                       attributes: [NSAttributedString.Key.foregroundColor: UIColor.white])
        
        refresher.addTarget(self, action: #selector(self.refresh), for: UIControl.Event.valueChanged)
        mainMenu.addSubview(refresher)
        
    }
    
    //MARK: User Actions
    
    @objc func utilities() {
        
        print("utilities")
        
        DispatchQueue.main.async {
            
            self.performSegue(withIdentifier: "goToUtilities", sender: self)
            
        }
        
    }
    
    @objc func createRaw() {
        
        if self.nodes.count > 0 {
                
            if isAnyNodeActive(nodes: self.nodes) {
                    
                DispatchQueue.main.async {
                    
                    self.performSegue(withIdentifier: "outgoings", sender: self)
                        
                }
                    
            } else {
                
                displayAlert(viewController: self, isError: true, message: "No active nodes")
                
            }
                
        } else {
            
            displayAlert(viewController: self, isError: true, message: "Add a node first")
            
        }
        
    }
    
    @objc func refresh() {
        print("refresh")
        
        DispatchQueue.main.async {
            
            self.transactionArray.removeAll()
            
            self.nodes.removeAll()
            
            self.nodes = self.cd.retrieveCredentials()
            
            let isActive = self.isAnyNodeActive(nodes: self.nodes)
            
            if isActive {
                
                let dispatchGroup = DispatchGroup()
                dispatchGroup.enter()
                
                for node in self.nodes {
                    
                    if (node["isActive"] as! Bool) {
                        
                        self.activeNode = node
                        self.existingNodeID = node["id"] as! String
                        
                        if UserDefaults.standard.object(forKey: "walletName") != nil {
                            
                            self.exisitingWallet = UserDefaults.standard.object(forKey: "walletName") as! String
                            
                        }
                        
                        dispatchGroup.leave()
                        
                    }
                    
                }
                
                dispatchGroup.notify(queue: DispatchQueue.main) {
                    
                    if let isDefault = self.activeNode["isDefault"] as? Bool {
                        
                        if isDefault {
                            
                            //displayAlert(viewController: self, isError: true, message: "Test node connected")
                            
                        }
                        
                    }
                    
                    let aes = AESService()
                    let enc = self.activeNode["label"] as! String
                    let dec = aes.decryptKey(keyToDecrypt: enc)
                    self.nodeLabel = dec
                    
                    self.connectingView.addConnectingView(vc: self,
                                                          description: "Connecting to \(dec)")
                    
                    if (self.activeNode["usingSSH"] as! Bool) {
                        
                        IsUsingSSH.sharedInstance = true
                        self.isUsingSSH = IsUsingSSH.sharedInstance
                        
                        self.ssh = SSHService.sharedInstance
                        self.ssh.activeNode = self.activeNode
                        
                        self.ssh.connect() { (success, error) in
                            
                            if success {
                                
                                print("connected succesfully")
                                self.makeSSHCall = SSHelper.sharedInstance
                                
                                self.loadTableDataSsh(method: BTC_CLI_COMMAND.getblockchaininfo,
                                                      param: "")
                                
                            } else {
                                
                                print("ssh fail")
                                self.removeSpinner()
                                
                                if error != nil {
                                    
                                    if error == "" {
                                        
                                        displayAlert(viewController: self,
                                                     isError: true,
                                                     message: String(describing: "Unable to authenticate SSH"))
                                        
                                    } else {
                                        
                                        displayAlert(viewController: self,
                                                     isError: true,
                                                     message: String(describing: error!))
                                        
                                    }
                                    
                                } else {
                                    
                                    displayAlert(viewController: self,
                                                 isError: true,
                                                 message: "Unable to connect")
                                    
                                }
                                
                            }
                            
                        }
                        
                    } else if (self.activeNode["usingTor"] as! Bool) {
                        
                        IsUsingSSH.sharedInstance = false
                        self.isUsingSSH = IsUsingSSH.sharedInstance
                        
                        // do not automatically disconnect tor, put the tor connection in settings so user can manually refresh
                        if self.torClient != nil {
                            
                            self.torClient.resign()
                            self.torClient = nil
                            self.removeSpinner()
                            
                            displayAlert(viewController: self,
                                         isError: true,
                                         message: "Tor thread disconnected, refresh to connect")
                            
                        } else {
                            
                            self.torClient = TorClient.sharedInstance
                            
                            func completed() {
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: {
                                    
                                    if self.torClient.isOperational {
                                        print("Tor connected")
                                        
                                        self.torRPC = MakeRPCCall.sharedInstance
                                        self.torRPC.torClient = self.torClient
                                        
                                        self.loadTableDataTor(method: BTC_CLI_COMMAND.getblockchaininfo,
                                                              param: "")
                                        
                                    } else {
                                        
                                        print("error connecting tor")
                                        
                                        self.removeSpinner()
                                        
                                        displayAlert(viewController: self,
                                                     isError: true,
                                                     message: "Unable to connect to Tor")
                                        
                                    }
                                    
                                })
                                
                            }
                            
                            self.torClient.start(completion: completed)
                            
                        }
                        
                    }
                    
                }
                
            } else {
                
                self.removeSpinner()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "No active nodes")
                
            }
            
        }
        
    }
    
    @objc func receive() {
        
        if self.nodes.count > 0 {
            
            if isAnyNodeActive(nodes: self.nodes) {
                
                DispatchQueue.main.async {
                    
                    self.performSegue(withIdentifier: "incoming", sender: self)
                    
                }
                
            } else {
                
                displayAlert(viewController: self, isError: true, message: "No active nodes")
                
            }
            
        } else {
            
            displayAlert(viewController: self, isError: true, message: "Add a node first")
            
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
            
        case "getTransaction":
            
            if let navController = segue.destination as? UINavigationController {
                
                if let childVC = navController.topViewController as? TransactionViewController {
                    
                    //childVC.isUsingSSH = self.isUsingSSH
                    childVC.txid = self.tx
                    
                }
                
            }
            
        default:
            
            break
            
        }
        
    }
    
    //MARK: Helpers
    
    func isAnyNodeActive(nodes: [[String:Any]]) -> Bool {
        
        var boolToReturn = false
        
        for node in nodes {
            
            let isActive = node["isActive"] as! Bool
            
            if isActive {
                
                boolToReturn = true
                
            }
            
        }
        
        return boolToReturn
        
    }
    
    func firstTimeHere() {
        
        let firstTime = FirstTime()
        firstTime.firstTimeHere()
        
    }
    
    func deleteAllNodes() {
        
        let cd = CoreDataService()
        let success = cd.deleteAllNodes(vc: self)
        
        if success {
            
            print("deleted all nodes")
            
        }
        
    }
    
    func convertCredentials() {
        
        if UserDefaults.standard.object(forKey: "hasConverted") == nil {
            
            let converter = CredentialConverter()
            converter.convertCredentials(vc: self)
            
        }
        
    }

}

extension Double {
    
    func withCommas() -> String {
        
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = NumberFormatter.Style.decimal
        return numberFormatter.string(from: NSNumber(value:self))!
        
    }
    
}

extension MainMenuViewController  {
    
    func tabBarController(_ tabBarController: UITabBarController,
                          animationControllerForTransitionFrom fromVC: UIViewController,
                          to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        
        return MyTransition(viewControllers: tabBarController.viewControllers)
        
    }
    
}
