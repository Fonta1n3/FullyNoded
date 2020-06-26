//
//  MainMenuViewController.swift
//  BitSense
//
//  Created by Peter on 08/09/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit

class MainMenuViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UINavigationControllerDelegate, OnionManagerDelegate {
    
    weak var mgr = TorClient.sharedInstance
    let backView = UIView()
    let ud = UserDefaults.standard
    var command = ""
    @IBOutlet var mainMenu: UITableView!
    var connectingView = ConnectingView()
    let cd = CoreDataService()
    var nodes = [[String:Any]]()
    var activeNode:[String:Any]?
    var existingNodeID:UUID!
    var initialLoad = Bool()
    var sectionOneLoaded = Bool()
    let spinner = UIActivityIndicatorView(style: .medium)
    var refreshButton = UIBarButtonItem()
    var dataRefresher = UIBarButtonItem()
    var viewHasLoaded = Bool()
    var nodeLabel = ""
    var detailImage = UIImage()
    var detailImageTint = UIColor()
    var detailHeaderText = ""
    var detailSubheaderText = ""
    var detailTextDescription = ""
    var homeStruct:HomeStruct!
    @IBOutlet weak var headerLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mainMenu.delegate = self
        mainMenu.alpha = 0
        mainMenu.tableFooterView = UIView(frame: .zero)
        initialLoad = true
        viewHasLoaded = false
        sectionOneLoaded = false
        addNavBarSpinner()
        showUnlockScreen()
        setFeeTarget()
        NotificationCenter.default.addObserver(self, selector: #selector(refreshNode), name: .refreshNode, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if initialLoad {
            addlaunchScreen()
            firstTimeHere() { [unowned vc = self] success in
                if !success {
                    displayAlert(viewController: vc, isError: true, message: "there was a critical error setting your devices encryption key, please delete and reinstall the app")
                } else {
                    if vc.mgr?.state != .started && vc.mgr?.state != .connected  {
                        displayAlert(viewController: self, isError: false, message: "Tor is bootstrapping, please wait")
                        vc.mgr?.start(delegate: self)
                    }
                }
            }
        }
    }
    
    private func setEncryptionKey() {
        firstTimeHere() { [unowned vc = self] success in
            if !success {
                displayAlert(viewController: vc, isError: true, message: "there was a critical error setting your devices encryption key, please delete and reinstall the app")
            }
        }
    }
    
    func torConnProgress(_ progress: Int) {
        print("progress = \(progress)")
    }
    
    func torConnFinished() {
        print("finished connecting")
        viewHasLoaded = true
        removeBackView()
        loadTable()
        displayAlert(viewController: self, isError: false, message: "Tor finished bootstrapping")
    }
    
    func torConnDifficulties() {
        displayAlert(viewController: self, isError: true, message: "We are having issues connecting tor")
    }
    
    func addNavBarSpinner() {
        spinner.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        dataRefresher = UIBarButtonItem(customView: spinner)
        navigationItem.setRightBarButton(dataRefresher, animated: true)
        spinner.startAnimating()
        spinner.alpha = 1
    }
    
    @objc func refreshNode() {
        existingNodeID = nil
        addNavBarSpinner()
        loadTable()
    }
    
    private func loadTable() {
        getNodes { [unowned vc = self] nodeArray in
            if nodeArray != nil {
                if nodeArray!.count > 0 {
                    vc.loopThroughNodes(nodes: nodeArray!)
                } else {
                    DispatchQueue.main.async { [unowned vc = self] in
                        vc.performSegue(withIdentifier: "addNodeNow", sender: vc)
                    }
                }
            }
            vc.initialLoad = false
        }
    }
    
    private func loopThroughNodes(nodes: [[String:Any]]) {
        var activeNode:[String:Any]?
        for (i, node) in nodes.enumerated() {
            let nodeStruct = NodeStruct.init(dictionary: node)
            if nodeStruct.isActive {
                activeNode = node
            }
            if i + 1 == nodes.count {
                if activeNode != nil {
                    loadNode(node: activeNode!)
                } else {
                    removeLoader()
                    connectingView.removeConnectingView()
                    showAlert(vc: self, title: "No Active Node", message: "Go to \"settings\" > \"node manager\" and toggle on one of your nodes.")
                }
            }
        }
    }
    
    private func loadNode(node: [String:Any]) {
        let nodeStruct = NodeStruct(dictionary: node)
        if initialLoad {
            existingNodeID = nodeStruct.id
            loadTableData()
        } else {
            checkIfNodesChanged(newNodeId: nodeStruct.id!)
        }
        DispatchQueue.main.async { [unowned vc = self] in
            vc.headerLabel.text = nodeStruct.label
        }
    }
    
    private func checkIfNodesChanged(newNodeId: UUID) {
        if newNodeId != existingNodeID {
            loadTableData()
        }
    }
    
    @objc func refreshData(_ sender: Any) {
        existingNodeID = nil
        refreshDataNow()
    }
    
    func refreshDataNow() {
        addNavBarSpinner()
        loadTable()
    }
    
    @IBAction func lockButton(_ sender: Any) {
        showUnlockScreen()
    }
    
    func showUnlockScreen() {
        if KeyChain.getData("UnlockPassword") != nil {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.performSegue(withIdentifier: "lockScreen", sender: vc)
            }
        }
    }
    
    //MARK: Tableview Methods
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 13
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func blankCell() -> UITableViewCell {
        let cell = UITableViewCell()
        cell.selectionStyle = .none
        cell.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        return cell
    }
    
    private func homeCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = mainMenu.dequeueReusableCell(withIdentifier: "homeCell", for: indexPath)
        cell.selectionStyle = .none
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.layer.borderWidth = 0.5
        let background = cell.viewWithTag(3)!
        let icon = cell.viewWithTag(1) as! UIImageView
        let label = cell.viewWithTag(2) as! UILabel
        let chevron = cell.viewWithTag(4) as! UIImageView
        background.clipsToBounds = true
        background.layer.cornerRadius = 8
        icon.tintColor = .white
        
        switch indexPath.section {
        case 0:
            if homeStruct.progress == "Fully verified" {
                background.backgroundColor = .systemGreen
                icon.image = UIImage(systemName: "checkmark.seal")
            } else {
                background.backgroundColor = .systemRed
                icon.image = UIImage(systemName: "exclamationmark.triangle")
            }
            label.text = homeStruct.progress
            chevron.alpha = 1
            
        case 1:
            label.text = "Bitcoin Core v\(homeStruct.version)"
            icon.image = UIImage(systemName: "v.circle")
            background.backgroundColor = .systemBlue
            chevron.alpha = 1
            
        case 2:
            label.text = homeStruct.network
            icon.image = UIImage(systemName: "link")
            if homeStruct.network == "test chain" {
                background.backgroundColor = .systemGreen
            } else if homeStruct.network == "main chain" {
                background.backgroundColor = .systemOrange
            } else {
                background.backgroundColor = .systemTeal
            }
            chevron.alpha = 1
            
        case 3:
            label.text = "\(homeStruct.outgoingCount) outgoing / \(homeStruct.incomingCount) incoming"
            icon.image = UIImage(systemName: "person.3")
            background.backgroundColor = .systemIndigo
            chevron.alpha = 1
            
        case 4:
            if homeStruct.pruned {
                label.text = "Pruned"
                icon.image = UIImage(systemName: "rectangle.compress.vertical")
                
            } else if !homeStruct.pruned {
                label.text = "Not pruned"
                icon.image = UIImage(systemName: "rectangle.expand.vertical")
            }
            background.backgroundColor = .systemPurple
            chevron.alpha = 1
            
        case 5:
            label.text = homeStruct.hashrate + " " + "EH/s hashrate"
            icon.image = UIImage(systemName: "speedometer")
            background.backgroundColor = .systemRed
            chevron.alpha = 0
            
        case 6:
            label.text = "\(homeStruct.blockheight.withCommas()) blocks"
            icon.image = UIImage(systemName: "square.stack.3d.up")
            background.backgroundColor = .systemYellow
            chevron.alpha = 0
            
        case 7:
            label.text = homeStruct.difficulty
            icon.image = UIImage(systemName: "slider.horizontal.3")
            background.backgroundColor = .systemBlue
            chevron.alpha = 0
            
        case 8:
            label.text = homeStruct.size
            background.backgroundColor = .systemPink
            icon.image = UIImage(systemName: "archivebox")
            chevron.alpha = 0
        
        case 9:
            label.text = "\(homeStruct.mempoolCount.withCommas()) mempool"
            icon.image = UIImage(systemName: "waveform.path.ecg")
            background.backgroundColor = .systemGreen
            chevron.alpha = 0
            
        case 10:
            label.text = homeStruct.feeRate + " " + "fee rate"
            icon.image = UIImage(systemName: "percent")
            background.backgroundColor = .systemGray
            chevron.alpha = 0
            
        case 11:
            if homeStruct.torReachable {
                label.text = "tor hidden service on"
                icon.image = UIImage(systemName: "wifi")
                background.backgroundColor = .black
                
            } else {
                label.text = "tor hidden service off"
                icon.image = UIImage(systemName: "wifi.slash")
                background.backgroundColor = .darkGray
            }
            chevron.alpha = 0
            
        case 12:
            label.text = "\(homeStruct.uptime / 86400) days \((homeStruct.uptime % 86400) / 3600) hours uptime"
            icon.image = UIImage(systemName: "clock")
            background.backgroundColor = .systemOrange
            chevron.alpha = 0
            
        default:
            break
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if sectionOneLoaded {
            return homeCell(indexPath)
        } else {
            return blankCell()
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = UIColor.clear
        header.frame = CGRect(x: 0, y: 0, width: view.frame.size.width - 32, height: 50)
        let textLabel = UILabel()
        textLabel.textAlignment = .left
        textLabel.font = UIFont.systemFont(ofSize: 20, weight: .regular)
        textLabel.textColor = .white
        textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
        
        switch section {
        case 0:
            textLabel.text = "Verification progress"
        case 1:
            textLabel.text = "Node version"
        case 2:
            textLabel.text = "Blockchain network"
        case 3:
            textLabel.text = "Peer connections"
        case 4:
            textLabel.text = "Blockchain state"
        case 5:
            textLabel.text = "Mining hashrate"
        case 6:
            textLabel.text = "Current blockheight"
        case 7:
            textLabel.text = "Mining difficulty"
        case 8:
            textLabel.text = "Blockchain size on disc"
        case 9:
            textLabel.text = "Node's mempool"
        case 10:
            textLabel.text = "Fee rate"
        case 11:
            textLabel.text = "P2P hidden service"
        case 12:
            textLabel.text = "Node uptime"
        default:
            break
        }
        
        header.addSubview(textLabel)
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            command = "getblockchaininfo"
            detailHeaderText = "Verification progress"
            if homeStruct.progress == "Fully verified" {
                detailImageTint = .systemGreen
                detailImage = UIImage(systemName: "checkmark.seal")!
            } else {
                detailImageTint = .systemRed
                detailImage = UIImage(systemName: "exclamationmark.triangle")!
            }
            detailSubheaderText = "\(homeStruct.actualProgress * 100)%"
            detailTextDescription = """
            Don't trust, verify!
            
            Simply put the "verification progress" field lets you know what percentage of the blockchain's transactions have been verified by your node. The value your node returns is a decimal number between 0.0 and 1.0. 1 meaning your node has verified 100% of the transactions on the blockchain. As new transactions and blocks are always being added to the blockchain your node is constantly catching up and this field will generally be a number such as "0.99999974646", never quite reaching 1 (although it is possible). Fully Noded checks if this number is greater than 0.99 (e.g. 0.999) and if it is we consider your node's copy of the blockchain to be "Fully Verified".
            
            Fully Noded makes the bitcoin-cli getblockchaininfo call to your node in order to get the "verification progress" of your node. Your node is always verifying each transaction that is broadcast onto the Bitcoin network. This is the fundamental reason to run your own node. If you use someone elses node you are trusting them to verify your utxo's which defeats the purpose of Bitcoin in the first place. Bitcoin was invented to disintermediate 3rd parties, removing trust from the foundation of our financial system, reintroducing that trust defeats Bitcoin's purpose. This is why it is so important to run your own node.
            
            During the initial block download your node proccesses each transaction starting from the genesis block, ensuring all the inputs and outputs of each transaction balance out with future transactions, this is possible because all transactions can be traced back to their coinbase transaction (also known as a "block reward"). This is true whether your node is pruned or not. In this way your node verifies all new transactions are valid, preventing double spending or inflation of the Bitcoin supply. You can think of it as preventing the counterfeiting of bitcoins as it would be impossible for an attacker to fake historic transactions in order to make the new one appear valid.
            """
            segueToShowDetail()
        case 1:
            command = "getnetworkinfo"
            detailHeaderText = "Node version"
            detailImageTint = .systemBlue
            detailImage = UIImage(systemName: "v.circle")!
            detailSubheaderText = "Bitcoin Core v\(homeStruct.version)"
            detailTextDescription = """
            The current version number of your node's software.
            
            Fully Noded makes the bitcoin-cli getnetworkinfo command to your node in order to obtain information about your node's connection to the Bitcoin peer to peer network. The command returns your node's current version number along with other info regarding your connections. To get the version number Fully Noded looks specifically at the "subversion" field.
            
            See the list of releases for each version along with detailed release notes.
            """
            segueToShowDetail()
        case 2:
            //"Blockchain network"
            command = "getblockchaininfo"
            detailHeaderText = "Blockchain network"
            detailSubheaderText = homeStruct.network
            if homeStruct.network == "test chain" {
                detailImageTint = .systemGreen
            } else if homeStruct.network == "main chain" {
                detailImageTint = .systemOrange
            } else {
                detailImageTint = .systemTeal
            }
            detailImage = UIImage(systemName: "link")!
            detailTextDescription = """
            Fully Noded makes the bitcoin-cli getblockchaininfo command to determine which network your node is running on. Your node can run three different chain's simultaneously; "main", "test" and "regtest". Fully Noded is capable of connecting to either one. To launch mutliple chains simultaneously you would want to run the "bitcoind" command with the "-chain=test", "-chain=regtest" arguments or omit the argument to run the main chain.
            
            It should be noted when running multiple chains simultaneously you can not specifiy the network in your bitcoin.conf file.
            
            The main chain is of course the real one, where real bitcoin can be spent and received.
            
            The test chain is called "testnet3" and is mostly for users who would like to test new functionality or get familiar with how bitcoin really works before commiting real funds. Its also usefull for developers and stress testing.
            
            The regtest chain is for developers who want to create their own personal blockchain, it is incredibly handy for developing bitcoin software as no internet is required and you can mine your own test bitcoins instantly. You may even setup multiple nodes and simulate specific kinds of network conditions.
            
            Fully Noded talks to each node via a port. Generally mainnet uses the default port 8332, testnet 18332 and regtest 18443. However because Fully Noded works over Tor we actually use what are called virtual ports under the hood. The rpcports as just mentioned are only ever exposed to your nodes localhost meaning they are only accessible remotely via a Tor hidden service.
            """
            segueToShowDetail()
        case 3:
            //"Peer connections"
            command = "getpeerinfo"
            detailHeaderText = "Peer connections"
            detailSubheaderText = "\(homeStruct.outgoingCount) outgoing / \(homeStruct.incomingCount) incoming"
            detailImage = UIImage(systemName: "person.3")!
            detailImageTint = .systemIndigo
            detailTextDescription = """
            Fully Noded makes the bitcoin-cli getpeerinfo command to your node in order to find out how many peers you are connected to.
                        
            You can have a number of incoming and outgoing peers, these are other nodes which your node is connected to over the peer to peer network (p2p). In order to receive incoming connections you can either forward port 8333 from your router or (more easily) use bitcoin core's built in functionality to create a hidden service using Tor to get incoming connections on, that way you can get incoming connections but do not need to forward a port.
            
            The p2p network is where your node receives all the information it needs about historic transactions when carrying out its initial block download and verification as well as all newly broadcast transactions.
            
            All new potential transactions are broadcast to the p2p network and whenever a peer learns of a new transaction it immedietly validates it and lets all of its peers know about the transaction, this is how bitcoin transactions propogate across the network. This way all nodes can stay up to date on the latest blocks/transactions.
            
            Check out this link for a deeper dive into the Bitcoin p2p network.
            """
            segueToShowDetail()
        case 4:
            //"Blockchain state"
            command = "getblockchaininfo"
            detailHeaderText = "Blockchain state"
            if homeStruct.pruned {
                detailSubheaderText = "Pruned"
                detailImage = UIImage(systemName: "rectangle.compress.vertical")!
                
            } else if !homeStruct.pruned {
                detailSubheaderText = "Not pruned"
                detailImage = UIImage(systemName: "rectangle.expand.vertical")!
            }
            detailImageTint = .systemPurple
            detailTextDescription = """
            Fully Noded makes the bitcoin-cli getblockchaininfo command to determine the blockchain's state. When configuring your node you can set "prune=1" or specifiy a size in mebibytes to prune the blockchain to.
            
            In this way you can avoid having to keep an entire copy of the blockchain on your computer, the minimum size is 550 mebibytes and the full current size is around 320gb.
            
            Pruned nodes still verify and validate every single transaction so no trust is needed to prune your node, however you can lose some convenient functionality like restoring old wallets that you may want to migrate to your new node.
            
            Once your initial block download and verification completes you can not "rescan" the blockchain past your prune height which is the block at which have pruned from.
            """
            segueToShowDetail()
//        case 5:
//            //"Mining hashrate"
//            segueToShowDetail()
//        case 6:
//            //"Current blockheight"
//            segueToShowDetail()
//        case 7:
//            //"Mining difficulty"
//            segueToShowDetail()
//        case 8:
//            //"Blockchain size on disc"
//            segueToShowDetail()
//        case 9:
//            //"Node's mempool"
//            segueToShowDetail()
//        case 10:
//            //"Fee rate"
//            segueToShowDetail()
//        case 11:
//            //"P2P hidden service"
//            segueToShowDetail()
//        case 12:
//            //"Node uptime"
//            segueToShowDetail()
        default:
            break
        }
    }
    
    private func segueToShowDetail() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "showDetailSegue", sender: vc)
        }
    }
    
    func loadTableData() {
        let nodeLogic = NodeLogic()
        displayAlert(viewController: self, isError: false, message: "bitcoin-cli getblockchaininfo")
        nodeLogic.loadSectionOne { [unowned vc = self] (response, errorMessage) in
            if errorMessage != nil {
                vc.removeLoader()
                displayAlert(viewController: self, isError: true, message: errorMessage!)
            } else if response != nil {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.homeStruct = HomeStruct(dictionary: response!)
                    vc.sectionOneLoaded = true
                    vc.mainMenu.reloadData()
                    vc.removeLoader()
                }
            }
        }
    }
    
    //MARK: User Interface
    
    func addlaunchScreen() {
        
        if let _ = self.tabBarController {
            
            DispatchQueue.main.async {
                
                self.backView.alpha = 0
                self.backView.frame = self.tabBarController!.view.frame
                self.backView.backgroundColor = .black
                let imageView = UIImageView()
                imageView.frame = CGRect(x: self.view.center.x - 75, y: self.view.center.y - 75, width: 150, height: 150)
                imageView.image = UIImage(named: "ItunesArtwork@2x.png")
                self.backView.addSubview(imageView)
                self.view.addSubview(self.backView)
                
                UIView.animate(withDuration: 0.8, animations: {
                    self.backView.alpha = 1
                })
                
            }
            
        }
        
    }
    
    func removeLoader() {
        
        DispatchQueue.main.async { [unowned vc = self] in
            
            vc.spinner.stopAnimating()
            vc.spinner.alpha = 0
            
            vc.refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: vc, action: #selector(vc.refreshData(_:)))
            
            vc.refreshButton.tintColor = UIColor.lightGray.withAlphaComponent(1)
            
            vc.navigationItem.setRightBarButton(vc.refreshButton,
                                                  animated: true)
            
            vc.viewHasLoaded = true
            
        }
        
    }
    
    func removeBackView() {
        
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.3, animations: {
                self.backView.alpha = 0
                self.mainMenu.alpha = 1
            }) { (_) in
                self.backView.removeFromSuperview()
            }
            
        }
        
    }
    
    func reloadTable() {
        //used when user switches between nodes so old node data is not displayed
        sectionOneLoaded = false
        
        DispatchQueue.main.async {
            
            self.mainMenu.reloadData()
            
        }
        
    }
    
    func getNodes(completion: @escaping (([[String:Any]]?)) -> Void) {
        
        nodes.removeAll()
        
        cd.retrieveEntity(entityName: .newNodes) {
            
            if !self.cd.errorBool {
                
                completion(self.cd.entities)
                
            } else {
                
                displayAlert(viewController: self, isError: true, message: "error getting nodes from coredata")
                completion(nil)
                
            }
            
        }
        
    }
    
    private func setFeeTarget() {
        if ud.object(forKey: "feeTarget") == nil {
            ud.set(1008, forKey: "feeTarget")
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
            
        case "showDetailSegue":
            
            if let vc = segue.destination as? ShowDetailViewController {
                vc.command = command
                vc.iconImage = detailImage
                vc.backgroundTint = detailImageTint
                vc.detailHeaderText = detailHeaderText
                vc.detailSubheaderText = detailSubheaderText
                vc.detailTextDescription = detailTextDescription
            }
            
        case "addNodeNow":
            
            if let vc = segue.destination as? ChooseConnectionTypeViewController {
                
                vc.cameFromHome = true
                
            }
            
        default:
            
            break
            
        }
        
    }
    
    //MARK: Helpers
    
    func firstTimeHere(completion: @escaping ((Bool)) -> Void) {
        FirstTime.firstTimeHere() { success in
            completion(success)
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
