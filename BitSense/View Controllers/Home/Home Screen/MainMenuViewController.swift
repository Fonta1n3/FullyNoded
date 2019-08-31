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
    let ud = UserDefaults.standard
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
    var transactionArray = [[String:Any]]()
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
    
    var sectionOneLoaded = Bool()
    
    @IBOutlet var spinner: UIActivityIndicatorView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("main menu")
        
        initialLoad = true
        let keychain = KeychainSwift()
        
        if ud.object(forKey: "updatedToSwift5") == nil {
            
            keychain.delete("UnlockPassword")
            keychain.delete("AESPassword")
            deleteAllNodes()
            ud.removeObject(forKey: "firstTime")
            
        }
        
        firstTimeHere()
        mainMenu.delegate = self
        tabBarController!.delegate = self
        configureRefresher()
        mainMenu.tableFooterView = UIView(frame: .zero)
        
        sectionOneLoaded = false
        
        if keychain.get("UnlockPassword") != nil {
            
            DispatchQueue.main.async {
                
                self.performSegue(withIdentifier: "lockScreen", sender: self)
                
            }
            
        }
        
        if ud.object(forKey: "feeTarget") == nil {
         
            ud.set(1008, forKey: "feeTarget")
            
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
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
                
                self.removeLoader()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "No active nodes")
                
            }
            
        } else {
            
            self.removeLoader()
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "Go to Nodes to add your own node")
            
        }
        
        initialLoad = false
            
    }
    
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
            
            if sectionOneLoaded {
                
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
                    
                    if ud.object(forKey: "walletName") != nil {
                        
                        wallet.text = (ud.object(forKey: "walletName") as! String)
                        
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
                
            } else {
                
                let nodeLabel = cell.viewWithTag(14) as! UILabel
                let wallet = cell.viewWithTag(9) as! UILabel
                
                nodeLabel.text = self.nodeLabel
                
                if ud.object(forKey: "walletName") != nil {
                    
                    wallet.text = (ud.object(forKey: "walletName") as! String)
                    
                } else {
                    
                    wallet.text = "Default"
                    
                }
                
                return cell
            }
            
        case 2:
            
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
            
            if transactionArray.count == 0 {
                
                loading.alpha = 1
                addressLabel.alpha = 0
                amountLabel.alpha = 0
                confirmationsLabel.alpha = 0
                labelLabel.alpha = 0
                dateLabel.alpha = 0
                watchOnlyLabel.alpha = 0
                
                return cell
                
            } else {
                
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
            
        } else if indexPath.section == 1 {
            
            if sectionOneLoaded {
                
                return 269
                
            } else {
                
                return 47
                
            }
            
        } else {
            
            if sectionOneLoaded {
                
              return 101
                
            } else {
                
                return 47
                
            }
            
            
            
        }
        
    }
    
    func loadSectionOne(connector: Connector) {
        
        let nodeLogic = NodeLogic()
        nodeLogic.ssh = ssh
        nodeLogic.helper = makeSSHCall
        
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
                
                DispatchQueue.main.async {
                    
                    self.removeSpinner()
                    self.mainMenu.reloadSections(IndexSet.init(arrayLiteral: 1),
                                                 with: .fade)
                    
                    self.loadSectionTwo(connector: connector)
                    
                }
                
            }
            
        }
        
        nodeLogic.loadSectionOne(completion: completion)
        
    }
    
    func loadSectionTwo(connector: Connector) {
        
        let nodeLogic = NodeLogic()
        nodeLogic.ssh = ssh
        nodeLogic.helper = makeSSHCall
        
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
                    self.spinner.stopAnimating()
                    self.spinner.alpha = 0
                    
                }
                
            }
            
        }
        
        nodeLogic.loadSectionTwo(completion: completion)
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.section == 1 {
            
            let connector = Connector()
            loadSectionOne(connector: connector)
            
        }
        
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
    
    //MARK: User Interface
    
    func removeLoader() {
        
        DispatchQueue.main.async {
            
            self.spinner.stopAnimating()
            self.spinner.alpha = 0
            
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
    
    @objc func refresh() {
        print("refresh")
        
        DispatchQueue.main.async {
            
            self.spinner.startAnimating()
            self.spinner.alpha = 1
            
            self.nodes.removeAll()
            
            self.nodes = self.cd.retrieveCredentials()
            
            let isActive = self.isAnyNodeActive(nodes: self.nodes)
            
            if isActive {
                
                let dispatchGroup = DispatchGroup()
                dispatchGroup.enter()
                
                for node in self.nodes {
                    
                    let nodeActive = node["isActive"] as! Bool
                    
                    if nodeActive {
                        
                        self.activeNode = node
                        self.existingNodeID = node["id"] as! String
                        
                        if self.ud.object(forKey: "walletName") != nil {
                            
                            self.exisitingWallet = self.ud.object(forKey: "walletName") as! String
                            
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
                    
                    let sshBool = self.activeNode["usingSSH"] as! Bool
                    let torBool = self.activeNode["usingTor"] as! Bool
                    let connector = Connector()
                    
                    if sshBool {
                        
                        self.connectSSH(connector: connector)
                        
                    } else if torBool {
                        
                        self.connectTor(connector: connector)
                        
                    }
                    
                }
                
            } else {
                
                self.removeSpinner()
                self.removeLoader()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "No active nodes")
                
            }
            
        }
        
    }
    
    func connectSSH(connector: Connector) {
        
        connector.activeNode = self.activeNode
        
        func completion() {
            
            if !connector.sshConnected {
                
                self.removeSpinner()
                self.removeLoader()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: connector.errorDescription ?? "Unable to connect via SSH")
                
            } else {
                
                self.loadSectionZero(connector: connector)
                
            }
            
        }
        
        connector.connectSSH(completion: completion)
        
    }
    
    func loadSectionZero(connector: Connector) {
        
        self.ssh = connector.ssh
        self.makeSSHCall = connector.makeSSHCall
        
        let nodeLogic = NodeLogic()
        nodeLogic.ssh = connector.ssh
        nodeLogic.helper = connector.makeSSHCall
        
        func completion() {
            
            if nodeLogic.errorBool {
                
                self.removeSpinner()
                self.removeLoader()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: nodeLogic.errorDescription)
                
            } else {
                
                let dict = nodeLogic.dictToReturn
                let sectionZeroStruct = HomeStruct(dictionary: dict)
                
                self.hotBalance = sectionZeroStruct.hotBalance
                self.coldBalance = sectionZeroStruct.coldBalance
                self.unconfirmedBalance = sectionZeroStruct.unconfirmedBalance
                
                DispatchQueue.main.async {
                    
                    self.removeSpinner()
                    self.mainMenu.reloadData()
                    self.loadSectionOne(connector: connector)
                    
                }
                
            }
            
        }
        
        nodeLogic.loadSectionZero(completion: completion)
        
    }
    
    func connectTor(connector:Connector) {
        
        func completion() {
            
            if !connector.torConnected {
                
                self.removeSpinner()
                self.removeLoader()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "Unable to connect to Tor")
                
            } else {
                
                self.torRPC = connector.torRPC
                
//                self.loadTableDataTor(method: BTC_CLI_COMMAND.getblockchaininfo,
//                                      param: "")
                
            }
            
        }
        
        connector.connectTor(completion: completion)
        
    }
    
    @objc func receive() {
        
        if self.nodes.count > 0 {
            
            if isAnyNodeActive(nodes: self.nodes) {
                
                DispatchQueue.main.async {
                    
                    self.performSegue(withIdentifier: "incoming", sender: self)
                    
                }
                
            } else {
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "No active nodes")
                
            }
            
        } else {
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "Add a node first")
            
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
            
        case "getTransaction":
            
            if let navController = segue.destination as? UINavigationController {
                
                if let childVC = navController.topViewController as? TransactionViewController {
                    
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
