//
//  MainMenuViewController.swift
//  BitSense
//
//  Created by Peter on 08/09/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit
import KeychainSwift

class MainMenuViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITabBarControllerDelegate, UINavigationControllerDelegate {
    
    let aes = AESService()
    let ud = UserDefaults.standard
    var hashrateString = String()
    var version = String()
    var incomingCount = Int()
    var outgoingCount = Int()
    var isPruned = Bool()
    var tx = String()
    var currentBlock = Int()
    var transactionArray = [[String:Any]]()
    @IBOutlet var mainMenu: UITableView!
    var refresher: UIRefreshControl!
    var connector:Connector!
    var connectingView = ConnectingView()
    let cd = CoreDataService()
    var nodes = [[String:Any]]()
    var uptime = Int()
    var activeNode = [String:Any]()
    var existingNodeID = ""
    var initialLoad = Bool()
    var existingWallet = ""
    var mempoolCount = Int()
    var walletDisabled = Bool()
    var torReachable = Bool()
    var progress = ""
    var difficulty = ""
    var feeRate = ""
    var size = ""
    var hotBalance = ""
    var coldBalance = ""
    var unconfirmedBalance = ""
    var network = ""
    var sectionZeroLoaded = Bool()
    var sectionOneLoaded = Bool()
    let spinner = UIActivityIndicatorView(style: .white)
    var refreshButton = UIBarButtonItem()
    var dataRefresher = UIBarButtonItem()
    var wallets = NSArray()
    var viewHasLoaded = Bool()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addCloseButtonToConnectingView()
        mainMenu.delegate = self
        mainMenu.tableFooterView = UIView(frame: .zero)
        tabBarController!.delegate = self
        initialLoad = true
        viewHasLoaded = false
        sectionZeroLoaded = false
        sectionOneLoaded = false
        checkIfUpdated()
        firstTimeHere()
        addNavBarSpinner()
        configureRefresher()
        setFeeTarget()
        showUnlockScreen()
        convertExistingDescriptors()
            
        self.connectingView.addConnectingView(vc: self.tabBarController!,
                                              description: "connecting")
            
        
    }
    
    func addNavBarSpinner() {
        
        spinner.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        dataRefresher = UIBarButtonItem(customView: spinner)
        navigationItem.setRightBarButton(dataRefresher, animated: true)
        spinner.startAnimating()
        spinner.alpha = 1
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        let walletName = ud.object(forKey: "walletName") as? String ?? ""
        let isActive = activeNodeDict().isAnyNodeActive
            
            if nodes.count > 0 {
                
                if isActive {
                    
                    activeNode = activeNodeDict().node
                    let node = NodeStruct(dictionary: activeNode)
                    let newId = node.id
                    IsUsingSSH.sharedInstance = node.usingSSH
                    
                    if newId != existingNodeID {
                        
                        if !initialLoad {
                            
                            ud.removeObject(forKey: "walletName")
                            existingWallet = ""
                            
                        }
                        
                        self.refresh()
                        
                    } else if walletName != existingWallet {
                        
                        if viewHasLoaded {
                            
                            existingWallet = walletName
                            reloadWalletData()
                            
                        }
                        
                    }
                    
                } else {
                    
                    self.removeLoader()
                    self.connectingView.removeConnectingView()
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: "no active nodes")
                    
                }
                
            } else {
                
                self.removeLoader()
                self.connectingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "go to Nodes to add your own node")
                
            }
            
        
        initialLoad = false
        
    }
    
    @objc func refreshData(_ sender: Any) {
        print("refreshData")
        
        if SSHService.sharedInstance.session != nil {
            
            if connector.ssh != nil {
                
                if connector.ssh.session.isConnected {
                    
                    refreshDataNow()
                    
                }
                
            } else if connector.torConnected {
            
                refreshDataNow()
                
            } else {
                
                refresh()
                
            }
                
        } else if connector.torConnected {
            
                refreshDataNow()
            
        } else {
            
            refresh()
            
        }
        
    }
    
    func convertExistingDescriptors() {
        
        let addDescriptors = AddDescriptors()
        addDescriptors.addDescriptorsToCoreData()
        
    }
    
    func refreshDataNow() {
        print("refreshDataNow")
        
        addNavBarSpinner()
        loadSectionZero()
        
    }
    
    @IBAction func lockButton(_ sender: Any) {
        
        showUnlockScreen()
        
    }
    
    func checkIfUpdated() {
        
        let keychain = KeychainSwift()
        
        if ud.object(forKey: "updatedToSwift5") == nil {
            
            keychain.delete("UnlockPassword")
            keychain.delete("AESPassword")
            let nodes = cd.retrieveEntity(entityName: .nodes)
            
            for node in nodes {
                
                let n = NodeStruct(dictionary: node)
                
                let _ = cd.deleteEntity(viewController: self,
                                        id: n.id,
                                        entityName: .nodes)
                
            }
            
            ud.removeObject(forKey: "firstTime")
            
        }
        
    }
    
    func setFeeTarget() {
        
        if ud.object(forKey: "feeTarget") == nil {
            
            ud.set(1008, forKey: "feeTarget")
            
        }
        
    }
    
    func showUnlockScreen() {
        
        let keychain = KeychainSwift()
        
        if keychain.get("UnlockPassword") != nil {
            
            DispatchQueue.main.async {
                
                self.performSegue(withIdentifier: "lockScreen", sender: self)
                
            }
            
        }
        
    }
    
    //MARK: Tableview Methods
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        return 3
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        switch section {
            
        case 2:
            
            if transactionArray.count > 0 {
                
                return transactionArray.count
                
            } else {
                
                return 1
                
            }
            
        default:
            
            return 1
            
        }
        
    }
    
    func blankCell() -> UITableViewCell {
        
        let cell = UITableViewCell()
        cell.selectionStyle = .none
        cell.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        switch indexPath.section {
            
        case 0:
            
            if sectionZeroLoaded {
                
                let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
                let hotBalanceLabel = cell.viewWithTag(1) as! UILabel
                let coldBalanceLabel = cell.viewWithTag(2) as! UILabel
                let unconfirmedLabel = cell.viewWithTag(3) as! UILabel
                
                if hotBalance == "" {
                    
                    self.hotBalance = "0.00000000"
                    
                }
                
                if coldBalance == "" {
                    
                    self.coldBalance = "0.00000000"
                    
                }
                
                hotBalanceLabel.text = self.hotBalance
                coldBalanceLabel.text = self.coldBalance
                unconfirmedLabel.text = self.unconfirmedBalance
                return cell
                
            } else {
                
                return blankCell()
                
            }
            
        case 1:
            
            if sectionOneLoaded {
                
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
                let mempool = cell.viewWithTag(10) as! UILabel
                let tor = cell.viewWithTag(11) as! UILabel
                let difficultyLabel = cell.viewWithTag(12) as! UILabel
                let sizeLabel = cell.viewWithTag(13) as! UILabel
                let feeRate = cell.viewWithTag(14) as! UILabel
                
                sizeLabel.text = self.size
                difficultyLabel.text = self.difficulty
                sync.text = self.progress
                feeRate.text = self.feeRate
                
                if torReachable {
                    
                    tor.text = "reachable"
                    
                } else {
                    
                    tor.text = "not reachable"
                    
                }
                
                mempool.text = self.mempoolCount.withCommas()
                
                if self.isPruned {
                    
                    pruned.text = "true"
                    
                } else if !self.isPruned {
                    
                    pruned.text = "false"
                }
                
                if self.network != "" {
                    
                    network.text = self.network
                    
                }
                
                blockHeight.text = "\(self.currentBlock.withCommas())"
                connections.text = "\(outgoingCount) out / \(incomingCount) in"
                version.text = self.version
                hashRate.text = self.hashrateString + " " + "EH/s"
                uptime.text = "\(self.uptime / 86400) days \((self.uptime % 86400) / 3600) hours"
                
                return cell
                
            } else {
                
                return blankCell()
                
            }
            
        case 2:
            
            if transactionArray.count == 0 {
                
                return blankCell()
                
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
                let loading = cell.viewWithTag(14) as! UILabel
                
                loading.alpha = 0
                addressLabel.alpha = 0
                amountLabel.alpha = 1
                confirmationsLabel.alpha = 1
                labelLabel.alpha = 1
                dateLabel.alpha = 1
                watchOnlyLabel.alpha = 1
                
                mainMenu.separatorColor = UIColor.white
                let dict = self.transactionArray[indexPath.row]
                
                addressLabel.text = dict["address"] as? String
                
                confirmationsLabel.text = (dict["confirmations"] as! String) + " " + "confs"
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
                
                let amount = dict["amount"] as! String
                
                if amount.hasPrefix("-") {
                    
                    amountLabel.text = amount
                    amountLabel.textColor = UIColor.darkGray
                    labelLabel.textColor = UIColor.darkGray
                    confirmationsLabel.textColor = UIColor.darkGray
                    dateLabel.textColor = UIColor.darkGray
                    
                } else {
                    
                    amountLabel.text = "+" + amount
                    amountLabel.textColor = UIColor.white
                    labelLabel.textColor = UIColor.white
                    confirmationsLabel.textColor = UIColor.white
                    dateLabel.textColor = UIColor.white
                    
                }
                
                return cell
                
            }
            
        default:
            
            return blankCell()
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        var sectionString = ""
        switch section {
        case 0: sectionString = ud.object(forKey: "walletName") as? String ?? "Default Wallet"
        case 1: sectionString = "Node stats"
        case 2: sectionString = "Transactions"
        default: break
        }
        return sectionString
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
        
        switch indexPath.section {
            
        case 0:
            
            if sectionZeroLoaded {
                
                return 142
                
            } else {
                
                return 47
                
            }
            
        case 1:
            
            if sectionOneLoaded {
                
                return 253
                
            } else {
                
                return 47
                
            }
            
        case 2:
            
            if sectionZeroLoaded {
                
                return 101
                
            } else {
                
                return 47
                
            }
            
        default:
            
            return 47
            
        }
        
    }
    
    func loadWalletFirst() {
        
        let nodeLogic = NodeLogic()
        
        func completion() {
            
            if nodeLogic.errorBool {
                
                if nodeLogic.errorDescription == "walletDisabled" {
                    
                    walletDisabled = true
                    loadSectionZero()
                    
                } else {
                    
                    self.removeSpinner()
                    self.removeLoader()
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: nodeLogic.errorDescription)
                    
                }
                
            } else {
                
                walletDisabled = false
                let wallets = nodeLogic.walletsToReturn
                
                switch wallets.count {
                    
                case 0:
                    
                    // this should never happen
                    print("?")
                    
                case 1:
                    
                    print("wallet is default")
                    loadSectionZero()
                    
                case 2:
                    
                    for w in wallets {
                        
                        let wallet = w as! String
                        
                        if wallet != "" {
                            
                            ud.set(wallet, forKey: "walletName")
                            existingWallet = wallet
                            
                            DispatchQueue.main.async {
                                
                                self.mainMenu.reloadSections(IndexSet.init(arrayLiteral: 0), with: .fade)
                                
                            }
                            
                        }
                        
                    }
                    
                    loadSectionZero()
                    
                default:
                    
                    //multiple wallets are loaded
                    
                    //check if walletName matches a loaded wallet, if no matches then more then one wallet is loaded that we dont know about so we get user to choose one
                    
                    self.wallets = wallets
                    var choose = false
                    
                    for w in wallets {
                        
                        let wallet = w as! String
                        
                        if let savedWallet = ud.object(forKey: "walletName") as? String {
                            
                            if wallet == savedWallet {
                                
                                //do nothing its already set to correct wallet
                                choose = false
                                
                            }
                            
                        } else {
                            
                            //get user to choose correct wallet
                            choose = true
                            
                        }
                        
                    }
                    
                    if choose {
                        
                        chooseAWallet()
                        
                    } else {
                        
                        loadSectionZero()
                        
                    }
                    
                }
                
            }
            
        }
        
        nodeLogic.loadWalletSection(completion: completion)
        
    }
    
    func chooseAWallet() {
        
        DispatchQueue.main.async {
            
            self.performSegue(withIdentifier: "chooseAWallet", sender: self)
            
        }
        
    }
    
    func loadSectionZero() {
        
        // dont show refresh button until a valid connection is made
        let nodeLogic = NodeLogic()
        nodeLogic.walletDisabled = walletDisabled
        
        func completion() {
            print("completion")
            
            if nodeLogic.errorBool {
                
                self.removeSpinner()
                self.removeLoader()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: nodeLogic.errorDescription)
                
            } else {
                
                let dict = nodeLogic.dictToReturn
                let str = HomeStruct(dictionary: dict)
                
                self.hotBalance = str.hotBalance
                self.coldBalance = str.coldBalance
                self.unconfirmedBalance = str.unconfirmedBalance
                
                DispatchQueue.main.async {
                    
                    self.sectionZeroLoaded = true
                    self.mainMenu.reloadSections(IndexSet.init(arrayLiteral: 0), with: .fade)
                    let impact = UIImpactFeedbackGenerator()
                    impact.impactOccurred()
                    //self.loadSectionOne()
                    self.loadSectionTwo()
                    
                }
                
            }
            
        }
        
        nodeLogic.loadSectionZero(completion: completion)
        
    }
    
    func loadSectionOne() {
        print("loadSectionOne")
        
        let nodeLogic = NodeLogic()
        nodeLogic.walletDisabled = walletDisabled
        
        func completion() {
            
            if nodeLogic.errorBool {
                
                self.removeLoader()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: nodeLogic.errorDescription)
                
            } else {
                
                let dict = nodeLogic.dictToReturn
                let str = HomeStruct(dictionary: dict)
                sectionOneLoaded = true
                feeRate = str.feeRate
                mempoolCount = str.mempoolCount
                network = str.network
                torReachable = str.torReachable
                size = str.size
                difficulty = str.difficulty
                progress = str.progress
                isPruned = str.pruned
                incomingCount = str.incomingCount
                outgoingCount = str.outgoingCount
                version = str.version
                hashrateString = str.hashrate
                uptime = str.uptime
                currentBlock = str.blockheight
                sectionOneLoaded = true
                
                DispatchQueue.main.async {
                    
                    self.mainMenu.reloadSections(IndexSet.init(arrayLiteral: 1),
                                                 with: .fade)
                    
                    let impact = UIImpactFeedbackGenerator()
                    impact.impactOccurred()
                    //self.loadSectionTwo()
                    self.removeLoader()
                    
                }
                
            }
            
        }
        
        nodeLogic.loadSectionOne(completion: completion)
        
    }
    
    func loadSectionTwo() {
        
        let nodeLogic = NodeLogic()
        nodeLogic.walletDisabled = walletDisabled
        
        func completion() {
            
            if nodeLogic.errorBool {
                
                self.removeLoader()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: nodeLogic.errorDescription)
                
            } else {
                
                transactionArray.removeAll()
                transactionArray = nodeLogic.arrayToReturn.reversed()
                
                DispatchQueue.main.async {
                    
                    self.mainMenu.reloadSections(IndexSet.init(arrayLiteral: 2),
                                                 with: .fade)
                    
                    let impact = UIImpactFeedbackGenerator()
                    impact.impactOccurred()
                    self.loadSectionOne()
                    
                    
                    
                }
                
            }
            
        }
        
        nodeLogic.loadSectionTwo(completion: completion)
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let impact = UIImpactFeedbackGenerator()
        
        DispatchQueue.main.async {
            
            impact.impactOccurred()
            
        }
        
        if indexPath.section == 0 {
            
            addNavBarSpinner()
            let converter = FiatConverter()
            
            func getResult() {
                
                if !converter.errorBool {
                    
                    let btcHot = self.hotBalance
                    let btcCold = self.coldBalance
                    let rate = converter.fxRate
                    let hotDouble = (Double(self.hotBalance)! * rate).withCommas()
                    let coldDouble = (Double(self.coldBalance)! * rate).withCommas()
                    self.hotBalance = "﹩\(hotDouble)"
                    self.coldBalance = "﹩\(coldDouble)"
                    
                    DispatchQueue.main.async {
                        
                        self.removeLoader()
                        self.mainMenu.reloadSections(IndexSet.init(arrayLiteral: 0), with: .fade)
                        
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        
                        self.hotBalance = btcHot
                        self.coldBalance = btcCold
                        self.mainMenu.reloadSections(IndexSet.init(arrayLiteral: 0), with: .fade)
                        
                    }
                    
                } else {
                    
                    removeLoader()
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: "error getting fiat rate")
                    
                }
                
            }
            
            converter.getFxRate(completion: getResult)
            
        } else {
            
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
        
    }
    
    //MARK: User Interface
    
    func removeLoader() {
        
        DispatchQueue.main.async {
            
            self.spinner.stopAnimating()
            self.spinner.alpha = 0
            
            self.refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh,
                                                 target: self,
                                                 action: #selector(self.refreshData(_:)))
            
            self.refreshButton.tintColor = UIColor.white.withAlphaComponent(1)
            
            self.navigationItem.setRightBarButton(self.refreshButton,
                                                  animated: true)
            
            self.viewHasLoaded = true
            
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
        
        refresher.attributedTitle = NSAttributedString(string: "pull to reconnect",
                                                       attributes: [NSAttributedString.Key.foregroundColor: UIColor.white])
        
        refresher.addTarget(self, action: #selector(self.refresh),
                            for: UIControl.Event.valueChanged)
        
        mainMenu.addSubview(refresher)
        
    }
    
    func reloadTable() {
        print("reloadTable")
        
        //used when user switches between nodes so old node data is not displayed
        sectionZeroLoaded = false
        sectionOneLoaded = false
        transactionArray.removeAll()
        
        DispatchQueue.main.async {
            
            self.mainMenu.reloadData()
            
        }
        
    }
    
    func activeNodeDict() -> (isAnyNodeActive: Bool, node: [String:Any]) {
        
        var dictToReturn = [String:Any]()
        var boolToReturn = false
        nodes.removeAll()
        nodes = cd.retrieveEntity(entityName: .nodes)
        
        for nodeDict in nodes {
            
            let node = NodeStruct(dictionary: nodeDict)
            let nodeActive = node.isActive
            
            if nodeActive {
                
                boolToReturn = true
                dictToReturn = nodeDict
                
            }
            
        }
        
        return (boolToReturn, dictToReturn)
        
    }
    
    func addCloseButtonToConnectingView() {
        
        let button = UIButton()
        button.setTitle("close", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15)
        button.setTitleColor(UIColor.darkGray, for: .normal)
        button.addTarget(self, action: #selector(closeConnectingView), for: .touchUpInside)
        let frame = connectingView.blurView.contentView.frame
        
        button.frame = CGRect(x: frame.midX - (80 / 2),
                              y: frame.maxY - 30,
                              width: 80,
                              height: 15)
        
        DispatchQueue.main.async {
            self.connectingView.blurView.contentView.addSubview(button)
        }
        
   }
    
    //MARK: User Actions
    
    @objc func closeConnectingView() {
        
        DispatchQueue.main.async {
            self.connectingView.removeConnectingView()
        }
        
    }
    
    @objc func refresh() {
        print("refresh")
        
        if TorClient.sharedInstance.isOperational {
            
            TorClient.sharedInstance.resign()
            
        }        
        
        DispatchQueue.main.async {
            
            if !self.initialLoad {
                
                
                self.connectingView.addConnectingView(vc: self.tabBarController!,
                                                      description: "connecting")
                
                self.addCloseButtonToConnectingView()
                
                
            }
            
            self.reloadTable()
            self.addNavBarSpinner()
            let anyNodeActive = self.activeNodeDict().isAnyNodeActive
            
            if anyNodeActive {
                
                self.activeNode = self.activeNodeDict().node
                let str = NodeStruct(dictionary: self.activeNode)
                self.existingNodeID = str.id
                let enc = str.label
                let dec = self.aes.decryptKey(keyToDecrypt: enc)
                self.navigationItem.title = dec
                let sshBool = str.usingSSH
                let torBool = str.usingTor
                self.connector = Connector()
                
                if sshBool {
                    
                    self.connectSSH(connector: self.connector)
                    
                } else if torBool {
                    
                    self.connectTor(connector: self.connector)
                    
                }
                
            } else {
                
                self.removeSpinner()
                self.removeLoader()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "no active nodes")
                
            }
            
        }
        
    }
    
    func connectSSH(connector: Connector) {
        
        connector.activeNode = self.activeNode
        
        func completion() {
            
            if !connector.sshConnected {
                
                removeSpinner()
                removeLoader()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: connector.errorDescription ?? "unable to connect via ssh")
                
            } else {
                
                viewHasLoaded = true
                removeSpinner()
                loadWalletFirst()
                
            }
            
        }
        
        connector.connectSSH(completion: completion)
        
    }
    
    func connectTor(connector:Connector) {
        
        func completion() {
            
            if !connector.torConnected {
                
                removeSpinner()
                removeLoader()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "unable to connect to tor")
                
            } else {
                
                viewHasLoaded = true
                removeSpinner()
                loadWalletFirst()
                
            }
            
        }
        
        connector.connectTor(completion: completion)
        
    }
    
    func reloadWalletData() {
        
        addNavBarSpinner()
        let nodeLogic = NodeLogic()
        nodeLogic.walletDisabled = false
        sectionZeroLoaded = false
        transactionArray.removeAll()
        
        DispatchQueue.main.async {
            
            self.mainMenu.reloadSections([0, 2], with: .fade)
            
        }
        
        func completion() {
            print("completion")
            
            if nodeLogic.errorBool {
                
                self.removeSpinner()
                self.removeLoader()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: nodeLogic.errorDescription)
                
            } else {
                
                let dict = nodeLogic.dictToReturn
                let str = HomeStruct(dictionary: dict)
                
                self.hotBalance = str.hotBalance
                self.coldBalance = (str.coldBalance)
                self.unconfirmedBalance = (str.unconfirmedBalance)
                
                DispatchQueue.main.async {
                    
                    self.sectionZeroLoaded = true
                    self.mainMenu.reloadSections(IndexSet.init(arrayLiteral: 0), with: .fade)
                    let impact = UIImpactFeedbackGenerator()
                    impact.impactOccurred()
                    
                    if !self.sectionOneLoaded {
                        
                        self.loadSectionOne()
                        
                    } else {
                        
                        self.loadSectionTwo()
                        
                    }
                    
                }
                
            }
            
        }
        
        nodeLogic.loadSectionZero(completion: completion)
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
            
        case "getTransaction":
            
            if let vc = segue.destination as? TransactionViewController {
                
                vc.txid = tx
                
            }
            
        case "chooseAWallet":
            
            if let vc = segue.destination as? ChooseWalletViewController {
                
                vc.wallets = wallets
                
            }
            
        default:
            
            break
            
        }
        
    }
    
    //MARK: Helpers
    
    func isAnyNodeActive(nodes: [[String:Any]]) -> Bool {
        
        var boolToReturn = false
        
        for nodeDict in nodes {
            
            let node = NodeStruct(dictionary: nodeDict)
            
            if node.isActive {
                
                boolToReturn = true
                
            }
            
        }
        
        return boolToReturn
        
    }
    
    func firstTimeHere() {
        
        let firstTime = FirstTime()
        firstTime.firstTimeHere()
        
    }
    
    func convertCredentials() {
        
        if ud.object(forKey: "hasConverted") == nil {
            
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
