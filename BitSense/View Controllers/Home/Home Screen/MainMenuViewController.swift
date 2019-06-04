//
//  MainMenuViewController.swift
//  BitSense
//
//  Created by Peter on 08/09/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit

class MainMenuViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITabBarControllerDelegate {
    
    let dateFormatter = DateFormatter()
    var syncStatus = String()
    var hashrateString = String()
    var version = String()
    var incomingCount = Int()
    var outgoingCount = Int()
    var isPruned = Bool()
    var isTestnet = Bool()
    var tx = String()
    var currentBlock = Int()
    var newFee = Double()
    var latestBlockHeight = Int()
    var balance = Double()
    let balancelabel = UILabel()
    let unconfirmedBalanceLabel = UILabel()
    var transactionArray = [[String: Any]]()
    @IBOutlet var mainMenu: UITableView!
    var refresher: UIRefreshControl!
    var ssh:SSHService!
    var makeSSHCall:SSHelper!
    var connectingView = ConnectingView()
    let notConnectedView = NoConnectionView()
    let plusImage = UIImageView()
    let minusImage = UIImageView()
    let cd = CoreDataService()
    var nodes = [[String:Any]]()
    let plusButton = UIButton()
    let minusButton = UIButton()
    let tests = Tests()
    var uptime = Int()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("main menu")
        
        firstTimeHere()
        mainMenu.delegate = self
        tabBarController!.delegate = self
        configureRefresher()
        mainMenu.tableFooterView = UIView(frame: .zero)
        addBalanceLabel()
        convertCredentials()
        refresh()
        
        plusButton.addTarget(self, action: #selector(receive), for: .touchUpInside)
        minusButton.addTarget(self, action: #selector(createRaw), for: .touchUpInside)
        
        plusButton.backgroundColor = UIColor.clear
        minusButton.backgroundColor = UIColor.clear
        
        plusImage.image = UIImage(named: "whitePlus.png")
        minusImage.image = UIImage(named: "whiteSubtract.png")
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        addBlurView(frame: CGRect(x: 10,
                                  y: tabBarController!.tabBar.frame.minY - 80,
                                  width: 70,
                                  height: 70), image: plusImage)
        
        addBlurView(frame: CGRect(x: view.frame.maxX - 80,
                                  y: tabBarController!.tabBar.frame.minY - 80,
                                  width: 70,
                                  height: 70), image: minusImage)
        
        plusButton.frame = CGRect(x: 10,
                                  y: tabBarController!.tabBar.frame.minY - 80,
                                  width: 70,
                                  height: 70)
        
        minusButton.frame = CGRect(x: view.frame.maxX - 80,
                                   y: tabBarController!.tabBar.frame.minY - 80,
                                   width: 70,
                                   height: 70)
        
        plusButton.removeFromSuperview()
        view.addSubview(plusButton)
        
        minusButton.removeFromSuperview()
        view.addSubview(minusButton)
        
    }
    
    //MARK: Tableview Methods
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        return 2
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        switch section {
            
        case 0:
            
            return 1
            
        case 1:
            
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
        
        if indexPath.section == 0 {
            
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
            
            if self.hashrateString != "" {
                
                notConnectedView.removeFromSuperview()
                
                if self.isPruned {
                    
                    pruned.text = "True"
                    
                } else if !self.isPruned {
                    
                    pruned.text = "False"
                }
                
                if self.isTestnet {
                    
                    network.text = "Testnet"
                    
                } else if !self.isTestnet {
                    
                    network.text = "Mainnet"
                    
                }
                
                blockHeight.text = "\(self.currentBlock)"
                connections.text = "\(outgoingCount) outgoing / \(incomingCount) incoming"
                version.text = self.version
                hashRate.text = self.hashrateString + " " + "h/s"
                sync.text = self.syncStatus
                uptime.text = "\(self.uptime / 86400) days \((self.uptime % 86400) / 3600) hours"
                
            } else {
                
                notConnectedView.addNoConnectionView(cell: cell)
                
            }
            
            return cell
            
        } else {
            
            if transactionArray.count == 0 {
                
                let cell = tableView.dequeueReusableCell(withIdentifier: "Cell",
                                                         for: indexPath)
                cell.selectionStyle = .none
                mainMenu.separatorColor = UIColor.clear
                
                return cell
                
            } else {
                
                let cell = tableView.dequeueReusableCell(withIdentifier: "MainMenuCell",
                                                         for: indexPath)
                
                mainMenu.separatorColor = UIColor.white
                cell.selectionStyle = .none
                let addressLabel = cell.viewWithTag(1) as! UILabel
                let amountLabel = cell.viewWithTag(2) as! UILabel
                let confirmationsLabel = cell.viewWithTag(3) as! UILabel
                let labelLabel = cell.viewWithTag(4) as! UILabel
                let dateLabel = cell.viewWithTag(5) as! UILabel
                let feeLabel = cell.viewWithTag(6) as! UILabel
                let dict = self.transactionArray[indexPath.row]
                
                addressLabel.text = dict["address"] as? String
                
                let amount = dict["amount"] as! String
                
                if amount.hasPrefix("-") {
                    
                    amountLabel.text = amount
                    
                } else {
                    
                    amountLabel.text = "+" + amount
                    
                }
                
                confirmationsLabel.text = (dict["confirmations"] as! String) + " " + "Confs"
                let label = dict["label"] as? String
                
                if label != "," {
                    
                   labelLabel.text = label
                    
                } else if label == "," {
                    
                    labelLabel.text = "No label"
                    
                }
                
                dateLabel.text = dict["date"] as? String
                
                if dict["fee"] as? String != "" {
                    
                    feeLabel.text = "Fee:" + " " + (dict["fee"] as! String)
                    
                }
                
                if dict["abandoned"] as? Bool == true {
                    
                    cell.backgroundColor = UIColor.red
                    
                }
                
                return cell
                
            }
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        if section == 0 {
            
            //return "Node info:"
            return ""
            
        } else if section == 1 {
            
            //return "Last 10 transactions:"
            return ""
            
        } else {
            
            return ""
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        
        (view as! UITableViewHeaderFooterView).backgroundView?.backgroundColor = UIColor.clear
        (view as! UITableViewHeaderFooterView).textLabel?.textAlignment = .left
        (view as! UITableViewHeaderFooterView).textLabel?.font = UIFont.init(name: "HiraginoSans-W6", size: 10)
        (view as! UITableViewHeaderFooterView).textLabel?.textColor = UIColor.darkGray
        
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        if section == 0 {
            
            return 10
            
        } else {
            
            return 10
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        if indexPath.section == 0 {
            
            return 159
            
        } else if indexPath.section == 1{
            
            return 108
            
        } else {
            
            return 0
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if transactionArray.count > 0 {
         
            if indexPath.section == 1 {
                
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
                let rbf = selectedTx["rbf"] as! String
                let txID = selectedTx["txID"] as! String
                self.tx = txID
                let replacedBy = selectedTx["replacedBy"] as! String
                let confirmations = selectedTx["confirmations"] as! String
                let amount = selectedTx["amount"] as! String
                
                UIPasteboard.general.string = txID
                
                if rbf == "yes" && replacedBy == "" && amount.hasPrefix("-") && !confirmations.hasPrefix("-") {
                    
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: "Bump the fee",
                                                      message: "This will create a new transaction with an increased fee and will invalidate the original.", preferredStyle: .actionSheet)
                        
                        alert.addAction(UIAlertAction(title: NSLocalizedString("Bump the fee", comment: ""),
                                                      style: .default,
                                                      handler: { (action) in
                                                        
                                                    self.loadTableDataSsh(method: BTC_CLI_COMMAND.bumpfee, param: "\"\(txID)\"")
                                                        
                        }))
                        
                        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""),
                                                      style: .cancel,
                                                      handler: { (action) in }))
                        
                        alert.popoverPresentationController?.sourceView = self.view
                        
                        self.present(alert, animated: true) {
                            
                        }
                    }
                    
                } else {
                    
                    let textToShare = [txID]
                    let activityViewController = UIActivityViewController(activityItems: textToShare,
                                                                          applicationActivities: nil)
                    activityViewController.popoverPresentationController?.sourceView = self.view
                    
                    self.present(activityViewController, animated: true) {}
                    
                }
                
            }
            
        }
        
    }
    
    //MARK: Result Parsers
    
    func parseMiningInfo(miningInfo: NSDictionary) {
        
        self.hashrateString = (miningInfo["networkhashps"] as! Double).withCommas()
        
        loadTableDataSsh(method: BTC_CLI_COMMAND.uptime,
                         param: "")
        
    }
    
    func parseNetworkInfo(networkInfo: NSDictionary) {
        
        self.version = (networkInfo["subversion"] as! String).replacingOccurrences(of: "/", with: "")
        
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
        
        if let chain = blockchainInfo["chain"] as? String {
            
            if chain == "test" {
                
                self.isTestnet = true
                self.getLatestBlock(isMainnet: false)
                
            } else {
                
                self.isTestnet = false
                self.getLatestBlock(isMainnet: true)
                
            }
            
        }
        
        if let pruned = blockchainInfo["pruned"] as? Bool {
            
            if pruned {
                
                self.isPruned = true
                
            } else {
                
                self.isPruned = false
                
            }
            
        }
        
        self.loadTableDataSsh(method: BTC_CLI_COMMAND.listtransactions,
                              param: "")
        
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
                
                if !self.isTestnet {
                    
                    self.unconfirmedBalanceLabel.text = "\(unconfirmedBalance.avoidNotation) Unconfirmed"
                    
                } else {
                    
                    self.unconfirmedBalanceLabel.text = "\(unconfirmedBalance.avoidNotation) Unconfirmed"
                    
                }
                
                UIView.animate(withDuration: 0.5, animations: {
                    
                    self.balancelabel.alpha = 1
                    self.unconfirmedBalanceLabel.alpha = 1
                    
                })
                
                self.loadTableDataSsh(method: BTC_CLI_COMMAND.getpeerinfo,
                                      param: "")
                
            }
            
        } else {
            
            DispatchQueue.main.async {
                
                if !self.isTestnet {
                    
                    self.unconfirmedBalanceLabel.text = "0 BTC Unconfirmed"
                    
                } else {
                    
                    self.unconfirmedBalanceLabel.text = "0 tBTC Unconfirmed"
                    
                }
                
                UIView.animate(withDuration: 0.5, animations: {
                    
                    self.balancelabel.alpha = 1
                    self.unconfirmedBalanceLabel.alpha = 1
                    
                })
                
                self.loadTableDataSsh(method: BTC_CLI_COMMAND.getpeerinfo,
                                      param: "")
                
            }
            
        }
        
    }
    
    func parseBalance(balance: Double) {
        
        self.balance = balance
        
        DispatchQueue.main.async {
            
            if !self.isTestnet {
                
                self.balancelabel.text = "\(balance.avoidNotation)" + " " + "BTC"
                
            } else {
                
                self.balancelabel.text = "\(balance.avoidNotation)" + " " + "tBTC"
                
            }
            
            self.loadTableDataSsh(method: BTC_CLI_COMMAND.getunconfirmedbalance,
                                  param: "")
            
        }
        
    }
    
    func parseTransactions(transactions: NSArray) {
        
        for item in transactions {
            
            if let transaction = item as? NSDictionary {
                
                var label = String()
                var fee = String()
                var replaced_by_txid = String()
                
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
                        
                        label = "No label"
                        
                    }
                    
                    if labelCheck == "," {
                        
                        label = "No label"
                        
                    }
                    
                } else {
                    
                    label = "No label"
                    
                }
                
                if let feeCheck = transaction["fee"] as? Double {
                    
                    fee = feeCheck.avoidNotation
                    
                }
                
                let secondsSince = transaction["time"] as! Double
                let rbf = transaction["bip125-replaceable"] as! String
                let txID = transaction["txid"] as! String
                
                let date = Date(timeIntervalSince1970: secondsSince)
                dateFormatter.dateFormat = "MMM-dd-yyyy HH:mm"
                let dateString = dateFormatter.string(from: date)
                
                self.transactionArray.append(["address": address,
                                              "amount": amountString,
                                              "confirmations": confirmations,
                                              "label": label,
                                              "date": dateString,
                                              "rbf": rbf,
                                              "txID": txID,
                                              "fee": fee,
                                              "replacedBy": replaced_by_txid])
                
            }
            
        }
        
        DispatchQueue.main.async {
            
            self.transactionArray = self.transactionArray.reversed()
            self.mainMenu.reloadData()
            
            /*UIView.animate(withDuration: 0.5) {
                
                self.mainMenu.alpha = 1
                
            }*/
            
        }
        
        self.loadTableDataSsh(method: BTC_CLI_COMMAND.getbalance,
                              param: "")
        
    }
    
    //MARK: SSH Commands
    
    func loadTableDataSsh(method: BTC_CLI_COMMAND, param: String) {
        print("loadTableDataRpc")
        
        func getResult() {
            print("get result")
            
            if !makeSSHCall.errorBool {
                
                switch method {
                    
                case BTC_CLI_COMMAND.uptime:
                    
                    self.uptime = Int(makeSSHCall.doubleToReturn)
                    
                    DispatchQueue.main.async {
                        
                        self.removeSpinner()
                        self.mainMenu.reloadData()
                        
                    }
                    
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
                    print("blockchainInfo = \(blockchainInfo)")
                    
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
                
                self.removeSpinner()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: makeSSHCall.errorDescription)
                
            }
            
        }
        
        if self.ssh.session.isAuthorized {
            
            if self.ssh.session.isConnected {
                
                self.makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                                       method: method,
                                                       param: param,
                                                       completion: getResult)
                
            } else {
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "Not connected")
                
            }
            
        }
        
    }
    
    
    //MARK: User Interface
    
    func addBlurView(frame: CGRect, image: UIImageView) {
        
        image.removeFromSuperview()
        let blur = UIView()
        
        image.frame = CGRect(x: 17.5,
                             y: 17.5,
                             width: 35,
                             height: 35)
        blur.frame = frame
        blur.clipsToBounds = true
        blur.layer.cornerRadius = frame.width / 2
        blur.backgroundColor = UIColor.black
        blur.addSubview(image)
        view.addSubview(blur)
        
    }
    
    func addBalanceLabel() {
        
        balancelabel.removeFromSuperview()
        unconfirmedBalanceLabel.removeFromSuperview()
        balancelabel.font = UIFont.init(name: "HiraginoSans-W3", size: 35)
        balancelabel.textColor = UIColor.white
        balancelabel.textAlignment = .center
        balancelabel.adjustsFontSizeToFitWidth = true
        balancelabel.alpha = 0
        view.addSubview(balancelabel)
        
        unconfirmedBalanceLabel.font = UIFont.init(name: "HiraginoSans-W3", size: 9)
        unconfirmedBalanceLabel.textColor = UIColor.white
        unconfirmedBalanceLabel.textAlignment = .center
        unconfirmedBalanceLabel.adjustsFontSizeToFitWidth = true
        unconfirmedBalanceLabel.alpha = 0
        view.addSubview(unconfirmedBalanceLabel)
        
    }
    
    override func viewWillLayoutSubviews() {
        
        let modelName = UIDevice.modelName
        
        switch modelName {
            
        case "Simulator iPhone X",
             "iPhone X",
             "Simulator iPhone XS",
             "Simulator iPhone XR",
             "Simulator iPhone XS Max",
             "iPhone XS",
             "iPhone XR",
             "iPhone XS Max",
             "Simulator iPhone11,8",
             "iPhone11,8",
             "Simulator iPhone11,2",
             "iPhone11,2",
             "Simulator iPhone11,4",
             "iPhone11,4",
             "iPhone10,3",
             "iPhone10,5",
             "iPhone10,6",
             "iPhone11,6":
            
            self.balancelabel.frame = CGRect(x: 0,
                                             y: 50,
                                             width: self.view.frame.width,
                                             height: 35)
            
            self.unconfirmedBalanceLabel.frame = CGRect(x: 0,
                                                        y: balancelabel.frame.maxY,
                                                        width: self.view.frame.width,
                                                        height: 15)
            
        default:
            
            
            self.balancelabel.frame = CGRect(x: 0,
                                             y: 40,
                                             width: self.view.frame.width,
                                             height: 35)
            
            self.unconfirmedBalanceLabel.frame = CGRect(x: 0,
                                                        y: balancelabel.frame.maxY,
                                                        width: self.view.frame.width,
                                                        height: 15)
            
        }
        
    }
    
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
        
        refresher.addTarget(self, action: #selector(self.refresh), for: UIControlEvents.valueChanged)
        mainMenu.addSubview(refresher)
        
    }
    
    //MARK: User Actions
    
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
        
        notConnectedView.removeFromSuperview()
        transactionArray.removeAll()
        addBalanceLabel()
        
        nodes.removeAll()
        nodes = cd.retrieveCredentials()
        var activeNode = [String:Any]()
        let isActive = isAnyNodeActive(nodes: nodes)
        
        if isActive {
            
            let dispatchGroup = DispatchGroup()
            dispatchGroup.enter()
            
            for node in nodes {
                
                if (node["isActive"] as! Bool) {
                    
                    activeNode = node
                    dispatchGroup.leave()
                    
                }
                
            }
            
            dispatchGroup.notify(queue: DispatchQueue.main) {
                
                if let isDefault = activeNode["isDefault"] as? Bool {
                    
                    if isDefault {
                        
                        //displayAlert(viewController: self, isError: true, message: "Test node connected")
                        
                    }
                    
                }
                
                self.connectingView.addConnectingView(vc: self,
                                                      description: "Connecting to \(activeNode["label"] as! String)")
                
                self.ssh = SSHService.sharedInstance
                
                self.ssh.connect(activeNode: activeNode) { (success, error) in
                    
                    if success {
                        
                        print("connected succesfully")
                        self.makeSSHCall = SSHelper.sharedInstance
                        
                        self.loadTableDataSsh(method: BTC_CLI_COMMAND.getblockchaininfo,
                                              param: "")
                        
                    } else {
                        
                        print("ssh fail")
                        self.removeSpinner()
                        
                        if error != nil {
                            
                            displayAlert(viewController: self,
                                         isError: true,
                                         message: String(describing: error!))
                            
                        } else {
                            
                            displayAlert(viewController: self,
                                         isError: true,
                                         message: "Unable to connect")
                            
                        }
                        
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
            
        case "outgoings":
            
            if let navController = segue.destination as? UINavigationController {
                
                if let childVC = navController.topViewController as? OutgoingsTableViewController {
                    
                    childVC.ssh = self.ssh
                    childVC.makeSSHCall = self.makeSSHCall
                    childVC.isTestnet = self.isTestnet
                    
                }
                
            }
            
        case "incoming":
            
            if let navController = segue.destination as? UINavigationController {
                
                if let childVC = navController.topViewController as? IncomingsTableViewController {
                    
                    childVC.ssh = self.ssh
                    childVC.makeSSHCall = self.makeSSHCall
                    childVC.isPruned = self.isPruned
                    
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
    
    func getLatestBlock(isMainnet: Bool) {
        print("getLatestBlock")
        
        var urlToUse:NSURL!
        
        if isMainnet {
            
            urlToUse = NSURL(string: "https://blockchain.info/latestblock")
            
        } else {
            
            urlToUse = NSURL(string: "https://testnet.blockchain.info/latestblock")
            
        }
        
        let task = URLSession.shared.dataTask(with: urlToUse as URL) { (data, response, error) -> Void in
            
            do {
                
                if error != nil {
                    
                    print(error as Any)
                    self.removeSpinner()
                    
                    DispatchQueue.main.async {
                        
                        displayAlert(viewController: self,
                                     isError: true,
                                     message: "\(String(describing: error!.localizedDescription))")
                        
                    }
                    
                } else {
                    
                    if let urlContent = data {
                        
                        do {
                            
                            let jsonAddressResult = try JSONSerialization.jsonObject(with: urlContent,
                                                                                     options: JSONSerialization.ReadingOptions.mutableLeaves) as! NSDictionary
                            
                            if let heightCheck = jsonAddressResult["height"] as? Int {
                                
                                self.latestBlockHeight = heightCheck
                                let percentage = (self.currentBlock * 100) / heightCheck
                                let percentageString = "\(percentage)%"
                                self.syncStatus = percentageString
                                
                            }
                            
                        } catch {
                            
                            print("JSon processing failed")
                            
                        }
                        
                    }
                    
                }
                
            }
            
        }
        
        task.resume()
        
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
